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

    private(set) var credentials: Credentials?
    private(set) var messages = CursorList<SentMessage>()
    private(set) var turns = CursorList<TerminalTurn>()
    private(set) var replies: [OutboundReply] = []
    /// One Swedish line about the last failure, or nil.
    private(set) var status: String?
    private(set) var notificationsAllowed: Bool?

    @ObservationIgnored private let credentialStore: CredentialStore
    @ObservationIgnored private let queue: ReplyQueue
    @ObservationIgnored private let messageFile: JSONFile<CursorList<SentMessage>>
    @ObservationIgnored private let turnFile: JSONFile<CursorList<TerminalTurn>>
    @ObservationIgnored private let transport: any Transport
    @ObservationIgnored private var pushToken: String?
    @ObservationIgnored private var loadingOlderMessages = false
    @ObservationIgnored private var loadingOlderTurns = false
    @ObservationIgnored private var followUp: Task<Void, Never>?

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
        queue = ReplyQueue(directory: directory)
        messageFile = JSONFile(directory: directory, name: "messages.json")
        turnFile = JSONFile(directory: directory, name: "terminal.json")
        transport = URLSessionTransport()
        credentials = credentialStore.load()
        if credentials != nil {
            messages = messageFile.load() ?? CursorList()
            turns = turnFile.load() ?? CursorList()
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
        guard credentials != nil else { return }
        await registerForPush()
    }

    func becameActive() async {
        guard credentials != nil else { return }
        await flush()
        await refreshMessages()
    }

    func pushArrived() async {
        guard credentials != nil else { return }
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
            status = Copy.saveFailed
            return false
        }
        credentials = saved
        status = nil
        messages = CursorList()
        turns = CursorList()
        await registerForPush()
        await flush()
        await refreshMessages()
        return true
    }

    /// Forgets the token, the caches, and the queue on this phone. The box
    /// keeps the device until the person revokes it there.
    func unpair() {
        try? credentialStore.forget()
        credentials = nil
        messages = CursorList()
        turns = CursorList()
        replies = []
        status = nil
        messageFile.delete()
        turnFile.delete()
        let queue = self.queue
        Task { await queue.clear() }
    }

    /// Moves the app to another kernel address with the same token.
    func changeKernel(to address: String) -> Bool {
        guard var current = credentials, let kernel = KernelAddress.parse(address) else { return false }
        current.kernel = kernel
        do {
            try credentialStore.save(current)
        } catch {
            status = Copy.saveFailed
            return false
        }
        credentials = current
        return true
    }

    // MARK: Messages

    func refreshMessages() async {
        guard let client else { return }
        do {
            let merged = try await NewestLoader.refresh(messages) { before, limit in
                try await client.messages(before: before, limit: limit)
            }
            messages = merged
            status = nil
            try? messageFile.save(merged.trimmed(to: AppModel.cachedItems))
        } catch {
            handle(error)
        }
    }

    func loadOlderMessages() async {
        guard let client, let before = messages.next, !loadingOlderMessages else { return }
        loadingOlderMessages = true
        defer { loadingOlderMessages = false }
        do {
            let page = try await client.messages(before: before)
            messages.appendOlder(page)
        } catch {
            handle(error)
        }
    }

    // MARK: Terminal

    func refreshTerminal() async {
        guard let client else { return }
        do {
            let merged = try await NewestLoader.refresh(turns) { before, limit in
                try await client.terminal(before: before, limit: limit)
            }
            turns = merged
            status = nil
            try? turnFile.save(merged.trimmed(to: AppModel.cachedItems))
        } catch {
            handle(error)
        }
    }

    func loadOlderTurns() async {
        guard let client, let before = turns.next, !loadingOlderTurns else { return }
        loadingOlderTurns = true
        defer { loadingOlderTurns = false }
        do {
            let page = try await client.terminal(before: before)
            turns.appendOlder(page)
        } catch {
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
            status = Copy.saveFailed
            return
        }
        await reloadReplies()
        await flush()
        if answers == nil {
            followTerminal()
        }
    }

    /// A text reply from a notification. The push names no message, so the
    /// reply answers the newest message the kernel lists when it arrives.
    func replyFromNotification(_ text: String) async {
        await refreshMessages()
        await send(text, answers: messages.newestID)
    }

    func retry(_ reply: OutboundReply) async {
        guard reply.state == .refused else {
            await flush()
            return
        }
        try? await queue.discard(id: reply.id)
        await send(reply.text, answers: reply.answers)
    }

    func discard(_ reply: OutboundReply) async {
        try? await queue.discard(id: reply.id)
        await reloadReplies()
    }

    func flush() async {
        guard let client else { return }
        let stop = await queue.flush(using: client)
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
        do {
            try await client.registerPush(token: hex)
        } catch {
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
            // 401 means the box no longer knows this token: pair again.
            try? credentialStore.forget()
            credentials = nil
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
