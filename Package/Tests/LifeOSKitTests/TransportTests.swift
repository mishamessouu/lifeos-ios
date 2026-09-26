import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import LifeOSKit

final class TransportTests: XCTestCase {
    // swift-corelibs-foundation stops the process when a URLProtocol fake
    // redirects, so this checks the delegate itself, not a live redirect.
    func testTheSessionRefusesEveryRedirect() throws {
        let transport = URLSessionTransport(timeout: 5)
        let delegate = try XCTUnwrap(transport.session.delegate as? NoRedirects)
        let from = URL(string: "https://box.example.invalid/api/terminal")!
        let to = URLRequest(url: URL(string: "https://elsewhere.example.invalid/")!)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: from, statusCode: 302, httpVersion: "HTTP/1.1", headerFields: ["Location": "https://elsewhere.example.invalid/"]
        ))
        let task = transport.session.dataTask(with: from)
        let answered = expectation(description: "completion")
        delegate.urlSession(transport.session, task: task, willPerformHTTPRedirection: response, newRequest: to) { request in
            XCTAssertNil(request)
            answered.fulfill()
        }
        wait(for: [answered], timeout: 1)
        task.cancel()
    }

    func testTheSessionKeepsNoCookiesAndNoCache() {
        let configuration = URLSessionTransport(timeout: 5).session.configuration
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertNil(configuration.urlCache)
    }

    func testAThreeHundredIsAServerError() async {
        let fake = FakeTransport(status: 302, body: "")
        await assertThrows(.server(status: 302, message: "")) { try await client(fake).messages() }
    }
}
