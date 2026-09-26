import Foundation
import XCTest
@testable import LifeOSKit

/// A transport that answers from a script and records every request.
final class FakeTransport: Transport, @unchecked Sendable {
    enum Step {
        case answer(Int, String)
        case fail
    }

    private let lock = NSLock()
    private var steps: [Step]
    private(set) var requests: [HTTPRequest] = []

    init(_ steps: [Step]) {
        self.steps = steps
    }

    convenience init(status: Int, body: String) {
        self.init([.answer(status, body)])
    }

    var sent: [HTTPRequest] {
        lock.lock(); defer { lock.unlock() }
        return requests
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let step: Step = {
            lock.lock(); defer { lock.unlock() }
            requests.append(request)
            return steps.isEmpty ? .fail : steps.removeFirst()
        }()
        switch step {
        case .answer(let status, let body):
            return HTTPResponse(status: status, body: Data(body.utf8))
        case .fail:
            throw TransportFailure("offline")
        }
    }
}

let kernelURL = URL(string: "https://box.example.invalid")!

func client(_ transport: FakeTransport, token: String? = "tok") -> Client {
    Client(kernel: kernelURL, token: token, transport: transport)
}

func json(_ data: Data?) -> [String: Any] {
    guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
    return object
}

func temporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("lifeoskit-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func message(_ id: String, _ text: String = "text") -> SentMessage {
    SentMessage(id: id, at: "2026-01-02T03:04:05Z", text: text, kind: .finding)
}

/// Asserts that an async call throws one ClientError.
func assertThrows<T>(
    _ expected: ClientError, file: StaticString = #filePath, line: UInt = #line,
    _ call: () async throws -> T
) async {
    do {
        _ = try await call()
        XCTFail("Expected \(expected), got a value.", file: file, line: line)
    } catch let error as ClientError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Expected \(expected), got \(error).", file: file, line: line)
    }
}
