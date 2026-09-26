import Foundation

/// What went wrong on one call, in words the app can map to one Swedish line.
public enum ClientError: Error, Hashable, Sendable {
    /// No token, or the kernel answered 401: the person pairs again.
    case notPaired
    /// No answer came back. The app keeps what it has and tries later.
    case offline
    /// The kernel answered with an error and one plain sentence.
    case server(status: Int, message: String)
    /// The kernel answered 2xx with a body this build cannot read.
    case unreadable

    /// A 5xx answer may pass on a retry; a 4xx answer will not.
    public var isRetryable: Bool {
        switch self {
        case .offline: true
        case .server(let status, _): status >= 500
        case .notPaired, .unreadable: false
        }
    }
}

/// The result of a good pairing.
public struct Pairing: Hashable, Sendable {
    public let device: PairedDevice
    public let token: String
}

/// Talks to one kernel. Every route under `/api/` carries the bearer token.
public struct Client: Sendable {
    public static let channel = "app"
    public static let pageLimit = 50

    public let kernel: URL
    public let token: String?
    let transport: any Transport

    public init(kernel: URL, token: String?, transport: any Transport = URLSessionTransport()) {
        self.kernel = kernel
        self.token = token
        self.transport = transport
    }

    public func with(token: String?) -> Client {
        Client(kernel: kernel, token: token, transport: transport)
    }

    // MARK: Routes

    /// `POST /api/pair`. Needs no token. Answers 201 with the device and the token.
    public func pair(_ code: PairingCode, name: String) async throws -> Pairing {
        let body = Wire.PairBody(code: code.text, name: name, bearer: true)
        let data = try await call("POST", "api/pair", body: try encode(body), authorized: false)
        guard let answer = try? JSONDecoder().decode(Wire.PairAnswer.self, from: data),
              !answer.token.isEmpty
        else { throw ClientError.unreadable }
        return Pairing(device: answer.device, token: answer.token)
    }

    /// `POST /api/channel/reply`. The same id sent again is taken once.
    public func reply(id: String, text: String, answers: String?) async throws -> ReplyAnswer {
        let body = Wire.ReplyBody(channel: Client.channel, id: id, text: text, answers: answers)
        return try taken(try await call("POST", "api/channel/reply", body: try encode(body)))
    }

    /// `POST /api/channel/press`. `data` is what one button carried.
    public func press(id: String, data: String) async throws -> ReplyAnswer {
        let body = Wire.PressBody(channel: Client.channel, id: id, data: data)
        return try taken(try await call("POST", "api/channel/press", body: try encode(body)))
    }

    /// `GET /api/channels/app/items`, newest first.
    public func items(before: String? = nil, limit: Int = Client.pageLimit) async throws -> Page<SentMessage> {
        let data = try await call("GET", "api/channels/\(Client.channel)/items", query: paging(before, limit))
        guard let page = try? JSONDecoder().decode(Wire.ItemsPage.self, from: data) else {
            throw ClientError.unreadable
        }
        return Page(items: page.items.elements, next: page.next)
    }

    /// `GET /api/terminal`, newest first as the kernel pages it.
    public func terminal(before: String? = nil, limit: Int = Client.pageLimit) async throws -> Page<TerminalTurn> {
        let data = try await call("GET", "api/terminal", query: paging(before, limit))
        guard let page = try? JSONDecoder().decode(Wire.TurnsPage.self, from: data) else {
            throw ClientError.unreadable
        }
        return Page(items: page.turns, next: page.next)
    }

    /// `POST /api/push/register` with the APNs device token as 64 lowercase hex letters.
    public func registerPush(token: String) async throws {
        guard PushToken.isValid(token) else {
            throw ClientError.server(status: 0, message: "The push token is not 64 hex letters.")
        }
        let data = try await call("POST", "api/push/register", body: try encode(Wire.PushBody(token: token)))
        guard let answer = try? JSONDecoder().decode(Wire.PushAnswer.self, from: data),
              answer.registered == true
        else { throw ClientError.unreadable }
    }

    // MARK: Plumbing

    private func paging(_ before: String?, _ limit: Int) -> [URLQueryItem] {
        var query = [URLQueryItem(name: "limit", value: String(max(1, limit)))]
        if let before { query.insert(URLQueryItem(name: "before", value: before), at: 0) }
        return query
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func taken(_ data: Data) throws -> ReplyAnswer {
        guard let answer = try? JSONDecoder().decode(Wire.TakenAnswer.self, from: data) else {
            throw ClientError.unreadable
        }
        if answer.ok == false {
            throw ClientError.server(status: 200, message: answer.error ?? "")
        }
        guard let taken = answer.taken else { throw ClientError.unreadable }
        return ReplyAnswer(taken: taken, reason: answer.reason)
    }

    func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var parts = URLComponents(url: kernel, resolvingAgainstBaseURL: false) ?? URLComponents()
        let prefix = parts.path.hasSuffix("/") ? String(parts.path.dropLast()) : parts.path
        parts.path = prefix + "/" + path
        parts.queryItems = query.isEmpty ? nil : query
        // `+` is legal in a query but some servers read it as a space.
        parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return parts.url ?? kernel
    }

    private func call(
        _ method: String, _ path: String, query: [URLQueryItem] = [],
        body: Data? = nil, authorized: Bool = true
    ) async throws -> Data {
        var headers = ["Accept": "application/json"]
        if body != nil { headers["Content-Type"] = "application/json" }
        if authorized {
            guard let token, !token.isEmpty else { throw ClientError.notPaired }
            headers["Authorization"] = "Bearer \(token)"
        }
        let request = HTTPRequest(method: method, url: url(path, query: query), headers: headers, body: body)
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch {
            throw ClientError.offline
        }
        if (200..<300).contains(response.status) { return response.body }
        let problem = try? JSONDecoder().decode(Wire.ErrorAnswer.self, from: response.body)
        if response.status == 401, authorized { throw ClientError.notPaired }
        if problem?.pair == true { throw ClientError.notPaired }
        throw ClientError.server(status: response.status, message: problem?.error ?? "")
    }
}

/// The APNs device token as the kernel wants it.
public enum PushToken {
    public static func hex(_ data: Data) -> String {
        data.map { byte in
            let digits = Array("0123456789abcdef")
            return String([digits[Int(byte >> 4)], digits[Int(byte & 0x0f)]])
        }.joined()
    }

    public static func isValid(_ text: String) -> Bool {
        text.count == 64 && text.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) }
    }
}
