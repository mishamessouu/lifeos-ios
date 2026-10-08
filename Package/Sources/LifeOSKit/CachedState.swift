import Foundation

/// What one read of the credentials gives the app.
public enum Restore: Hashable, Sendable {
    /// Paired: the credentials and the lists kept on disk for them.
    case paired(Credentials, messages: CursorList<SentMessage>, turns: CursorList<TerminalTurn>)
    /// No token. The files kept for a token are gone.
    case unpaired
    /// The Keychain refused the read, for example before the first unlock.
    /// Every file stays, and the app reads again later.
    case waiting
}

/// The credentials and the files kept for them: messages.json,
/// terminal.json, and the reply queue. It holds one rule: nothing on disk
/// outlives its token, and a refused read deletes nothing.
@MainActor
public final class CachedState {
    public let queue: ReplyQueue
    /// What the launch read found.
    public let launch: Restore
    /// True while the Keychain refuses the credentials read.
    public private(set) var waiting: Bool

    private let credentialStore: CredentialStore
    private let messageFile: JSONFile<CursorList<SentMessage>>
    private let turnFile: JSONFile<CursorList<TerminalTurn>>

    public init(directory: URL, keychain: any KeychainStore) {
        try? ProtectedFiles.prepare(directory: directory)
        credentialStore = CredentialStore(keychain: keychain)
        messageFile = JSONFile(directory: directory, name: "messages.json")
        turnFile = JSONFile(directory: directory, name: "terminal.json")
        let read = credentialStore.read()
        if read.dropsCachedFiles {
            messageFile.delete()
            turnFile.delete()
            ReplyQueue.deleteFile(in: directory)
        }
        queue = ReplyQueue(directory: directory)
        waiting = read == .unreadable
        switch read {
        case .found(let credentials):
            launch = .paired(
                credentials,
                messages: messageFile.load() ?? CursorList(),
                turns: turnFile.load() ?? CursorList()
            )
        case .absent:
            launch = .unpaired
        case .unreadable:
            launch = .waiting
        }
    }

    /// Reads the credentials again after a refused read. Returns nil when
    /// no read is due. A `.paired` result comes once per process, so the
    /// app does the launch work it skipped (push registration) then.
    public func readAgain() async -> Restore? {
        guard waiting else { return nil }
        switch credentialStore.read() {
        case .unreadable:
            return .waiting
        case .absent:
            waiting = false
            await dropFiles()
            return .unpaired
        case .found(let credentials):
            waiting = false
            await queue.reload()
            return .paired(
                credentials,
                messages: messageFile.load() ?? CursorList(),
                turns: turnFile.load() ?? CursorList()
            )
        }
    }

    /// Saves the credentials of a new pairing. The files from before go,
    /// since they may belong to an earlier pairing kept through a refused
    /// read. If the save fails, nothing changes.
    public func pair(_ credentials: Credentials) async throws {
        try credentialStore.save(credentials)
        waiting = false
        await dropFiles()
    }

    /// Saves changed credentials of the same pairing, for example a new
    /// kernel address. The files stay.
    public func update(_ credentials: Credentials) throws {
        try credentialStore.save(credentials)
    }

    /// Forgets the token and every file kept for it.
    public func forget() async {
        try? credentialStore.forget()
        waiting = false
        await dropFiles()
    }

    public func save(messages: CursorList<SentMessage>, keeping count: Int) {
        try? messageFile.save(messages.trimmed(to: count))
    }

    public func save(turns: CursorList<TerminalTurn>, keeping count: Int) {
        try? turnFile.save(turns.trimmed(to: count))
    }

    private func dropFiles() async {
        messageFile.delete()
        turnFile.delete()
        await queue.clear()
    }
}
