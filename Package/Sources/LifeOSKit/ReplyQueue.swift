import Foundation

/// One reply the person wrote. It waits in the queue on disk until the
/// kernel answers, so a reply written offline goes out on the next launch.
public struct OutboundReply: Identifiable, Hashable, Sendable, Codable {
    public enum State: String, Hashable, Sendable, Codable {
        /// Not confirmed by the kernel yet. The app shows "Inte skickat".
        case unsent
        /// The kernel took it.
        case sent
        /// The kernel answered and did not take it, or the app could not
        /// send it as written. `reason` holds the kernel's own sentence,
        /// for example when the message it answers is no longer open.
        case refused
    }

    /// The client reply id, a lowercase UUID. It never changes, so a resend
    /// is taken once by the kernel.
    public let id: String
    public let text: String
    /// The id of the sent message it answers, or nil for a plain Terminal entry.
    public let answers: String?
    public let createdAt: Date
    public var state: State
    public var reason: String?
    public var attempts: Int

    public init(
        id: String = ReplyID.make(), text: String, answers: String?,
        createdAt: Date = Date(), state: State = .unsent, reason: String? = nil, attempts: Int = 0
    ) {
        self.id = id
        self.text = text
        self.answers = answers
        self.createdAt = createdAt
        self.state = state
        self.reason = reason
        self.attempts = attempts
    }
}

/// The reply queue. It persists every change before it sends, sends in the
/// order the person wrote, and stops at the first reply the network or the
/// pairing holds back, so replies never overtake each other.
public actor ReplyQueue {
    /// Settled replies kept for the screen, newest last.
    public static let keepSettled = 50

    private let file: JSONFile<[OutboundReply]>
    private var replies: [OutboundReply]
    private var flushing = false

    public init(directory: URL) {
        file = JSONFile(directory: directory, name: "replies.json")
        replies = file.load() ?? []
    }

    public var all: [OutboundReply] { replies }
    public var unsent: [OutboundReply] { replies.filter { $0.state == .unsent } }

    /// Adds one reply and writes the queue before anything is sent. Throws
    /// `ClientError.invalid` for an empty text or one over 64 KiB.
    @discardableResult
    public func enqueue(text: String, answers: String?, now: Date = Date()) throws -> OutboundReply {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ClientError.invalid("The reply is empty.") }
        guard trimmed.utf8.count <= Client.maxTextBytes else {
            throw ClientError.invalid("The text is longer than 64 KiB.")
        }
        let reply = OutboundReply(text: trimmed, answers: answers, createdAt: now)
        replies.append(reply)
        try persist()
        return reply
    }

    /// Sends every unsent reply in order. Returns the error that stopped it,
    /// or nil when the queue is empty of unsent replies.
    @discardableResult
    public func flush(
        send: (OutboundReply) async throws -> ReplyAnswer
    ) async -> ClientError? {
        // One flush at a time. A second caller returns at once; the running
        // flush already sends every unsent reply.
        guard !flushing else { return nil }
        flushing = true
        defer { flushing = false }
        var stop: ClientError?
        var tried = Set<String>()
        // Reads the queue again each turn, so a reply added while this
        // flush waits on the network goes out in the same flush.
        while stop == nil,
              let reply = replies.first(where: { $0.state == .unsent && !tried.contains($0.id) }) {
            tried.insert(reply.id)
            do {
                let answer = try await send(reply)
                update(reply.id) {
                    $0.attempts += 1
                    $0.state = answer.taken ? .sent : .refused
                    $0.reason = answer.taken ? nil : answer.reason
                }
            } catch let error as ClientError {
                update(reply.id) { $0.attempts += 1 }
                if error.isRetryable || error == .notPaired {
                    stop = error
                } else {
                    // The kernel will not take this reply as written; resending changes nothing.
                    update(reply.id) {
                        $0.state = .refused
                        switch error {
                        case .server(_, let message) where !message.isEmpty: $0.reason = message
                        case .invalid(let words): $0.reason = words
                        default: break
                        }
                    }
                }
            } catch {
                update(reply.id) { $0.attempts += 1 }
                stop = .offline
            }
            try? persist()
        }
        prune()
        try? persist()
        return stop
    }

    /// Sends through a client.
    @discardableResult
    public func flush(using client: Client) async -> ClientError? {
        await flush { reply in
            try await client.reply(id: reply.id, text: reply.text, answers: reply.answers)
        }
    }

    /// Drops a reply the person gave up on.
    public func discard(id: String) throws {
        replies.removeAll { $0.id == id }
        try persist()
    }

    /// Empties the queue, for unpair.
    public func clear() {
        replies = []
        file.delete()
    }

    private func update(_ id: String, _ change: (inout OutboundReply) -> Void) {
        guard let index = replies.firstIndex(where: { $0.id == id }) else { return }
        change(&replies[index])
    }

    private func prune() {
        let settled = replies.filter { $0.state != .unsent }
        guard settled.count > Self.keepSettled else { return }
        let drop = Set(settled.prefix(settled.count - Self.keepSettled).map(\.id))
        replies.removeAll { drop.contains($0.id) }
    }

    private func persist() throws {
        try file.save(replies)
    }
}
