import Foundation
import LifeOSKit
import Observation
import UIKit
import UserNotifications

/// The app's one state holder. Rules live in LifeOSKit; this class wires
/// them to the Keychain, the files, and the screens.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    /// Set when a UI test launches the app: memory Keychain, empty files.
    static let isUITest = ProcessInfo.processInfo.arguments.contains("-lifeos-ui-test")

    private(set) var credentials: Credentials? = nil
    private(set) var messages = CursorList<SentMessage>()
    private(set) var turns = CursorList<TerminalTurn>()
    private(set) var replies: [OutboundReply] = []
    /// One Swedish line about the last failure, or nil.
    private(set) var status: String? = nil
    private(set) var notificationsAllowed: Bool? = nil

    private let credentialStore: CredentialStore
    private let queue: ReplyQueue
    private let messageFile: JSONFile<CursorList<SentMessage>>
    private let turnFile: JSONFile<CursorList<TerminalTurn>>
    private let transport: any Transport
    /// True while the Keychain refused the credentials read, for example on a
    /// launch before the first unlock. The files stay, and the app reads again.
    @ObservationIgnored private var credentialsUnreadable = false
    @ObservationIgnored private var pushToken: String? = nil
    @ObservationIgnored private var loadingOlderMessages = false
    @ObservationIgnored private var loadingOlderTurns = false
    @ObservationIgnored private var followUp: Task<Void, Never>? = nil
    @ObservationIgnored private var pushFetch: Task<Void, Never>? = nil
    /// Moves on every pairing and every reset. Work that awaited checks it
    /// before it writes, so a refresh in flight cannot write back after unpair.
    @ObservationIgnored private var generation = 0
    /// True when the last older page failed, so the list offers a retry.
    private(set) var olderMessagesFailed = false

    /// Items kept on disk between launches.
    static let cachedItems = 200

    init() {
        let directory: URL
        let keychain: any KeychainStore
        if AppModel.isUITest {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("lifeos-ui-test-\(UUID().uuidString)", isDirectory: true)
            keychain = MemoryKeychain()
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            directory = support.appendingPathComponent("LifeOS", isDirectory: true)
            keychain = SystemKeychain()
        }
        try? ProtectedFiles.prepare(directory: directory)
        credentialStore = CredentialStore(keychain: keychain)
        messageFile = JSONFile(directory: directory, name: "messages.json")
        turnFile = JSONFile(directory: directory, name: "terminal.json")
        transport = URLSessionTransport()
        let read = credentialStore.read()
        if read.dropsCachedFiles {
            // No token means nothing on disk may outlive it.
            messageFile.delete()
            turnFile.delete()
            ReplyQueue.deleteFile(in: directory)
        }
        queue = ReplyQueue(directory: directory)
        credentialsUnreadable = read == .unreadable
        if case .found(let stored) = read {
            credentials = stored
            messages = messageFile.load() ?? CursorList()
            turns = turnFile.load() ?? CursorList()
        }
    }

    /// Reads the credentials again after an unreadable launch read. Returns
    /// true when the app is now paired.
    private func readCredentialsAgain() async -> Bool {
        guard credentials == nil, credentialsUnreadable else { return credentials != nil }
        let read = credentialStore.read()
        switch read {
        case .unreadable:
            return false
        case .absent:
            credentialsUnreadable = false
            messageFile.delete()
            turnFile.delete()
            await queue.clear()
            await reloadReplies()
            return false
        case .found(let stored):
            credentialsUnreadable = false
            generation += 1
            credentials = stored
            messages = messageFile.load() ?? CursorList()
            turns = turnFile.load() ?? CursorList()
            return true
        }
    }

    private var client: Client? {
        guard let credentials else { return nil }
        return Client(kernel: credentials.kernel, token: credentials.token, transport: transport)
    }

    // MARK: Derived lists for the screens

    var messageGroups: [DayGroup<SentMessage>] {
        DayGroup.group(messages.items, date: { $0.at })
    }

    /// The Terminal shows the oldest turn at the top and the newest at the bottom.
    var turnsOldestFirst: [TerminalTurn] {
        Array(turns.items.reversed())
    }

    /// Terminal replies the kernel has not taken yet, or refused.
    var pendingTerminalReplies: [OutboundReply] {
        replies.filter { $0.answers == nil && $0.state != .sent }
    }

    func replies(answering id: String) -> [OutboundReply] {
        replies.filter { $0.answers == id }
    }

    // MARK: Lifecycle

    func launched() async {
        await reloadReplies()
        guard await readCredentialsAgain() else { return }
        await registerForPush()
    }

    /// Every return to the foreground sends the queue and fetches once (FetchPlan).
    func becameActive() async {
        guard await readCredentialsAgain() else { return }
        await flush()
        await FetchPlan.run(.foreground) {
            await self.fetchNewest()
        }
    }

    /// A push fetches at once and again three seconds later (FetchPlan), since
    /// the kernel may mark the message delivered only after the push returns.
    /// A newer push replaces the wait of an older one.
    func pushArrived() async {
        guard credentials != nil else { return }
        pushFetch?.cancel()
        let plan = Task { @MainActor [weak self] in
            await FetchPlan.run(.push) {
                await self?.fetchNewest()
            }
        }
        pushFetch = plan
        await plan.value
    }

    private func fetchNewest() async {
        await refreshMessages()
        await refreshTerminal()
    }

    // MARK: Pairing

    /// Pairs with a pasted link or code. Returns true when the app is paired.
    func pair(text: String, address: String, name: String) async -> Bool {
        guard let input = PairingInput.parse(text) else {
            status = Copy.badCode
            return false
        }
        guard let kernel = input.kernel ?? KernelAddress.parse(address) else {
            status = Copy.badAddress
            return false
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let pairing: Pairing
        do {
            pairing = try await Client(kernel: kernel, token: nil, transport: transport)
                .pair(input.code, name: trimmedName.isEmpty ? "iPhone" : trimmedName)
        } catch let error as ClientError {
            if case .server(let code, _) = error, code == 403 {
                status = Copy.codeRefused
            } else {
                status = line(for: error)
            }
            return false
        } catch {
            status = Copy.offline
            return false
        }
        let saved = Credentials(
            kernel: kernel, token: pairing.token,
            deviceID: pairing.device.id, deviceName: pairing.device.name
        )
        do {
            try credentialStore.save(saved)
        } catch {
            status = Copy.keySaveFailed
            return false
        }
        generation += 1
        credentialsUnreadable = false
        credentials = saved
        status = nil
        messages = CursorList()
        turns = CursorList()
        if let pushToken {
            await pushTokenArrived(pushToken)
        }
        await registerForPush()
        await flush()
        await refreshMessages()
        return true
    }

    /// Unpair on this phone. The box keeps the device until the person
    /// revokes it there.
    func unpair() async {
        await resetEverything()
        status = nil
    }

    /// The one place that forgets everything: the token and the kernel
    /// address (one Keychain item), messages.json, terminal.json, and
    /// replies.json. Used by unpair and by a 401 that asks to pair again.
    func resetEverything() async {
        generation += 1
        pushFetch?.cancel()
        followUp?.cancel()
        try? credentialStore.forget()
        credentialsUnreadable = false
        credentials = nil
        messages = CursorList()
        turns = CursorList()
        replies = []
        olderMessagesFailed = false
        messageFile.delete()
        turnFile.delete()
        await queue.clear()
    }

    /// Moves the app to another kernel address with the same token.
    func changeKernel(to address: String) -> Bool {
        guard var current = credentials, let kernel = KernelAddress.parse(address) else { return false }
        current.kernel = kernel
        do {
            try credentialStore.save(current)
        } catch {
            status = Copy.keySaveFailed
            return false
        }
        credentials = current
        return true
    }

    // MARK: Messages

    func refreshMessages() async {
        guard let client else { return }
        let started = generation
        do {
            let merged = try await NewestLoader.refresh(messages) { before, limit in
                try await client.messages(before: before, limit: limit)
            }
            guard started == generation else { return }
            messages = merged
            status = nil
            try? messageFile.save(merged.trimmed(to: AppModel.cachedItems))
        } catch {
            guard started == generation else { return }
            handle(error)
        }
    }

    func loadOlderMessages() async {
        guard let client, let before = messages.next, !loadingOlderMessages else { return }
        loadingOlderMessages = true
        olderMessagesFailed = false
        defer { loadingOlderMessages = false }
        let started = generation
        do {
            let page = try await client.messages(before: before)
            guard started == generation else { return }
            messages.appendOlder(page)
        } catch {
            guard started == generation else { return }
            olderMessagesFailed = true
            handle(error)
        }
    }

    // MARK: Terminal

    func refreshTerminal() async {
        guard let client else { return }
        let started = generation
        do {
            let merged = try await NewestLoader.refresh(turns) { before, limit in
                try await client.terminal(before: before, limit: limit)
            }
            guard started == generation else { return }
            turns = merged
            status = nil
            try? turnFile.save(merged.trimmed(to: AppModel.cachedItems))
        } catch {
            guard started == generation else { return }
            handle(error)
        }
    }

    func loadOlderTurns() async {
        guard let client, let before = turns.next, !loadingOlderTurns else { return }
        loadingOlderTurns = true
        defer { loadingOlderTurns = false }
        let started = generation
        do {
            let page = try await client.terminal(before: before)
            guard started == generation else { return }
            turns.appendOlder(page)
        } catch {
            guard started == generation else { return }
            handle(error)
        }
    }

    // MARK: Replies

    /// Puts one reply in the queue on disk, then sends the queue.
    /// `answers` is the id of the sent message it answers, or nil for the Terminal.
    func send(_ text: String, answers: String?) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await queue.enqueue(text: trimmed, answers: answers)
        } catch ClientError.invalid(_) {
            status = Copy.tooLong
            return
        } catch {
            status = Copy.replySaveFailed
            return
        }
        await reloadReplies()
        await flush()
        if answers == nil {
            followTerminal()
        }
    }

    /// A text reply from a notification. The push names no message, so the
    /// reply is a Terminal entry (`answers` nil). It goes to the queue on
    /// disk first, then out.
    func replyFromNotification(_ text: String) async {
        await send(text, answers: nil)
    }

    /// Försök igen: the same queued reply, with the same id.
    func retry(_ reply: OutboundReply) async {
        if reply.state == .refused {
            _ = try? await queue.requeue(id: reply.id)
            await reloadReplies()
        }
        await flush()
    }

    func discard(_ reply: OutboundReply) async {
        try? await queue.discard(id: reply.id)
        await reloadReplies()
    }

    func flush() async {
        guard let client else { return }
        let started = generation
        let stop = await queue.flush(using: client)
        guard started == generation else { return }
        await reloadReplies()
        if let stop {
            handle(stop)
        }
    }

    private func reloadReplies() async {
        replies = await queue.all
    }

    /// The Assistant answers a Terminal entry later, in its own Run. The
    /// Terminal reads again a few times so the answer shows without a pull.
    private func followTerminal() {
        followUp?.cancel()
        followUp = Task { [weak self] in
            for seconds in [2, 5, 10, 20, 40] as [UInt64] {
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                if Task.isCancelled { return }
                await self?.refreshTerminal()
            }
        }
    }

    // MARK: Push

    func registerForPush() async {
        if AppModel.isUITest { return }
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        notificationsAllowed = granted
        // Register on every launch: the kernel drops a token APNs no longer knows.
        UIApplication.shared.registerForRemoteNotifications()
    }

    func pushTokenArrived(_ hex: String) async {
        pushToken = hex
        guard let client else { return }
        let started = generation
        do {
            try await client.registerPush(token: hex)
        } catch ClientError.invalid(_) {
            status = Copy.badPushToken
        } catch {
            guard started == generation else { return }
            handle(error)
        }
    }

    func refreshNotificationSetting() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationsAllowed = true
        case .denied:
            notificationsAllowed = false
        default:
            notificationsAllowed = nil
        }
    }

    // MARK: Errors

    private func handle(_ error: Error) {
        guard let error = error as? ClientError else {
            status = Copy.offline
            return
        }
        if error == .notPaired {
            // 401 with pair true: the box no longer knows this token. Forget
            // everything, then show why on the pairing screen.
            Task {
                await self.resetEverything()
                self.status = Copy.notPaired
            }
            return
        }
        status = line(for: error)
    }

    private func line(for error: ClientError) -> String {
        switch error {
        case .offline: Copy.offline
        case .notPaired: Copy.notPaired
        case .unreadable: Copy.unreadable
        case .invalid: Copy.tooLong
        case .server(_, let message): message.isEmpty ? Copy.serverFailed : Copy.server(message)
        }
    }
}
