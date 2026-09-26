import Foundation

/// The kind of one message the kernel sent to the app Channel.
public enum Kind: Hashable, Sendable, Codable {
    case finding
    case digest
    case question
    case answer
    case note
    case notice
    /// A kind this build does not know. The row still shows.
    case other(String)

    public init(rawValue: String) {
        switch rawValue {
        case "finding": self = .finding
        case "digest": self = .digest
        case "question": self = .question
        case "answer": self = .answer
        case "note": self = .note
        case "notice": self = .notice
        default: self = .other(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .finding: "finding"
        case .digest: "digest"
        case .question: "question"
        case .answer: "answer"
        case .note: "note"
        case .notice: "notice"
        case .other(let raw): raw
        }
    }

    /// The short Swedish label the list shows beside the time.
    public var label: String {
        switch self {
        case .finding: "Fynd"
        case .digest: "Dagens fokus"
        case .question: "Fråga"
        case .answer: "Svar"
        case .note: "Anteckning"
        case .notice: "Varning"
        case .other: "Meddelande"
        }
    }

    /// The SF Symbol name for the kind. The app draws it; the package only names it.
    public var symbol: String {
        switch self {
        case .finding: "sparkle.magnifyingglass"
        case .digest: "sun.max"
        case .question: "questionmark.bubble"
        case .answer: "text.bubble"
        case .note: "note.text"
        case .notice: "exclamationmark.triangle"
        case .other: "envelope"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// One message the kernel sent to the app Channel. It lists newest first.
public struct SentMessage: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    /// The raw time as the kernel wrote it, kept so a cache round trip loses nothing.
    public let atText: String?
    public let text: String
    public let kind: Kind
    public let run: String?
    public let finding: String?

    public var at: Date? { KernelTime.parse(atText) }

    public init(
        id: String, at: String?, text: String, kind: Kind,
        run: String? = nil, finding: String? = nil
    ) {
        self.id = id
        self.atText = at
        self.text = text
        self.kind = kind
        self.run = run
        self.finding = finding
    }

    enum CodingKeys: String, CodingKey {
        case id, at, text, kind, run, finding
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(LooseID.self, forKey: .id).value
        atText = try c.decodeIfPresent(String.self, forKey: .at)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .other("")
        run = try c.decodeIfPresent(LooseID.self, forKey: .run)?.value
        finding = try c.decodeIfPresent(LooseID.self, forKey: .finding)?.value
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(atText, forKey: .at)
        try c.encode(text, forKey: .text)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(run, forKey: .run)
        try c.encodeIfPresent(finding, forKey: .finding)
    }

    /// The non-empty lines of the text, trimmed.
    var lines: [String] {
        text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// The first lines of the text, for one list row.
    public func preview(lines count: Int = 3) -> String {
        lines.prefix(count).joined(separator: "\n")
    }

    /// The first line, which a row shows in bold, the way Mail shows a subject.
    public var title: String { lines.first ?? "" }

    /// The lines after the title, for the secondary preview under it.
    public func rest(lines count: Int = 2) -> String {
        lines.dropFirst().prefix(count).joined(separator: "\n")
    }
}

/// Who wrote one Terminal turn.
public enum Role: Hashable, Sendable, Codable {
    case you
    case assistant
    case other(String)

    public init(rawValue: String) {
        switch rawValue {
        case "you": self = .you
        case "assistant": self = .assistant
        default: self = .other(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .you: "you"
        case .assistant: "assistant"
        case .other(let raw): raw
        }
    }

    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// One Terminal entry, or one answer to it.
public struct TerminalTurn: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let role: Role
    public let text: String
    public let atText: String?
    public let run: String?
    public let source: String?

    public var at: Date? { KernelTime.parse(atText) }

    public init(
        id: String, role: Role, text: String, at: String?,
        run: String? = nil, source: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.atText = at
        self.run = run
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case id, role, text, at, run, source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(LooseID.self, forKey: .id).value
        role = try c.decodeIfPresent(Role.self, forKey: .role) ?? .other("")
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        atText = try c.decodeIfPresent(String.self, forKey: .at)
        run = try c.decodeIfPresent(LooseID.self, forKey: .run)?.value
        source = try c.decodeIfPresent(String.self, forKey: .source)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(role, forKey: .role)
        try c.encode(text, forKey: .text)
        try c.encodeIfPresent(atText, forKey: .at)
        try c.encodeIfPresent(run, forKey: .run)
        try c.encodeIfPresent(source, forKey: .source)
    }
}

/// The app as the kernel lists it after pairing. Never holds the token.
public struct PairedDevice: Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let createdAt: String?
    public let lastSeenAt: String?

    public init(id: String, name: String, createdAt: String? = nil, lastSeenAt: String? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
    }
}

/// One page of a list the kernel pages by cursor. `next` is the `before`
/// value for the page after this one, or nil at the end.
public struct Page<Item: Sendable & Hashable>: Sendable, Hashable {
    public let items: [Item]
    public let next: String?

    public init(items: [Item], next: String?) {
        self.items = items
        self.next = next
    }
}

/// What the kernel said about one reply or press.
public struct ReplyAnswer: Hashable, Sendable {
    public let taken: Bool
    public let reason: String?

    public init(taken: Bool, reason: String? = nil) {
        self.taken = taken
        self.reason = reason
    }
}

/// An id the kernel may write as a string or a number. Kept as text.
struct LooseID: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let text = try? c.decode(String.self) {
            value = text
        } else if let number = try? c.decode(Int64.self) {
            value = String(number)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                .init(codingPath: decoder.codingPath, debugDescription: "An id must be text or a whole number.")
            )
        }
    }
}
