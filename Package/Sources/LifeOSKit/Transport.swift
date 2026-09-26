import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One HTTP request, free of URLSession so tests can fake the network.
public struct HTTPRequest: Sendable, Hashable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?

    public init(method: String, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

/// One HTTP answer.
public struct HTTPResponse: Sendable, Hashable {
    public var status: Int
    public var body: Data

    public init(status: Int, body: Data = Data()) {
        self.status = status
        self.body = body
    }
}

/// Sends one request. A transport throws `TransportFailure` when no answer came.
public protocol Transport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

/// No answer came back: no network, no route to the kernel, or a timeout.
public struct TransportFailure: Error, Sendable, Hashable {
    public let detail: String
    public init(_ detail: String) { self.detail = detail }
}

/// The real transport. It keeps no cookies and no cache: the token is the check.
public final class URLSessionTransport: Transport, @unchecked Sendable {
    // URLSession is thread safe; `@unchecked` because it is not marked Sendable on every platform.
    private let session: URLSession

    public init(timeout: TimeInterval = 20) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        urlRequest.httpBody = request.body
        let session = self.session
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: urlRequest) { data, response, error in
                if let error {
                    continuation.resume(throwing: TransportFailure(error.localizedDescription))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    continuation.resume(throwing: TransportFailure("No HTTP answer."))
                    return
                }
                continuation.resume(returning: HTTPResponse(status: http.statusCode, body: data ?? Data()))
            }
            task.resume()
        }
    }
}
