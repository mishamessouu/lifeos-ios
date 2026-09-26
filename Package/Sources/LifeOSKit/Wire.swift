import Foundation

/// The JSON shapes of the kernel routes, decoded here and nowhere else.
enum Wire {
    /// A list that drops an element it cannot read instead of failing the page.
    struct Lossy<Element: Decodable>: Decodable {
        let elements: [Element]

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var kept: [Element] = []
            while !container.isAtEnd {
                if let element = try? container.decode(Element.self) {
                    kept.append(element)
                } else {
                    _ = try? container.decode(Skip.self)
                }
            }
            elements = kept
        }
    }

    /// Reads and throws away one JSON value of any shape.
    struct Skip: Decodable {
        init(from decoder: Decoder) throws {}
    }

    /// The Channel page. The kernel names the list `messages`; an early
    /// draft named it `items`, and both are read.
    struct MessagesPage: Decodable {
        let messages: [SentMessage]
        let next: String?

        enum CodingKeys: String, CodingKey { case messages, items, next }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let messages = try c.decodeIfPresent(Lossy<SentMessage>.self, forKey: .messages) {
                self.messages = messages.elements
            } else if let items = try c.decodeIfPresent(Lossy<SentMessage>.self, forKey: .items) {
                self.messages = items.elements
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.messages,
                    .init(codingPath: c.codingPath, debugDescription: "No messages list.")
                )
            }
            next = try c.decodeIfPresent(LooseID.self, forKey: .next)?.value
        }
    }

    /// The Terminal page. The kernel names the list `turns`; `messages` is read too.
    struct TurnsPage: Decodable {
        let turns: [TerminalTurn]
        let next: String?

        enum CodingKeys: String, CodingKey { case turns, messages, next }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let turns = try c.decodeIfPresent(Lossy<TerminalTurn>.self, forKey: .turns) {
                self.turns = turns.elements
            } else if let messages = try c.decodeIfPresent(Lossy<TerminalTurn>.self, forKey: .messages) {
                self.turns = messages.elements
            } else {
                throw DecodingError.keyNotFound(
                    CodingKeys.turns,
                    .init(codingPath: c.codingPath, debugDescription: "No turns or messages list.")
                )
            }
            next = try c.decodeIfPresent(LooseID.self, forKey: .next)?.value
        }
    }

    struct PairBody: Encodable {
        let code: String
        let name: String
        let bearer: Bool
    }

    struct PairAnswer: Decodable {
        let device: PairedDevice
        let token: String
    }

    struct ReplyBody: Encodable {
        let channel: String
        let id: String
        let text: String
        let answers: String?

        enum CodingKeys: String, CodingKey { case channel, id, text, answers }

        // `answers` goes as JSON null when absent, as the route expects.
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(channel, forKey: .channel)
            try c.encode(id, forKey: .id)
            try c.encode(text, forKey: .text)
            if let answers {
                try c.encode(answers, forKey: .answers)
            } else {
                try c.encodeNil(forKey: .answers)
            }
        }
    }

    struct PressBody: Encodable {
        let channel: String
        let id: String
        let data: String
    }

    struct TakenAnswer: Decodable {
        let ok: Bool?
        let taken: Bool?
        let reason: String?
        let error: String?
    }

    struct PushBody: Encodable {
        let token: String
    }

    struct PushAnswer: Decodable {
        let registered: Bool?
    }

    struct ErrorAnswer: Decodable {
        let error: String?
        let pair: Bool?
    }
}
