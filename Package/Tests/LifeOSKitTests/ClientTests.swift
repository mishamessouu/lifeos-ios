import Foundation
import XCTest
@testable import LifeOSKit

final class ClientTests: XCTestCase {
    // MARK: Pair

    func testPairPostsTheCodeWithBearerAndNoToken() async throws {
        let fake = FakeTransport(
            status: 201,
            body: #"{"device": {"id": "0123456789ab", "name": "iPhone", "created_at": "2026-01-01T00:00:00Z", "last_seen_at": null}, "token": "secret-token"}"#
        )
        let code = try XCTUnwrap(PairingCode("0a1b2c3d.abcdefghijklmnopqrstuvwx"))
        let pairing = try await client(fake, token: nil).pair(code, name: "iPhone")
        XCTAssertEqual(pairing.token, "secret-token")
        XCTAssertEqual(pairing.device.id, "0123456789ab")
        XCTAssertEqual(pairing.device.name, "iPhone")
        XCTAssertEqual(pairing.device.createdAt, "2026-01-01T00:00:00Z")
        XCTAssertNil(pairing.device.lastSeenAt)
        let request = try XCTUnwrap(fake.sent.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.absoluteString, "https://box.example.invalid/api/pair")
        XCTAssertNil(request.headers["Authorization"])
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertNil(request.headers["Origin"])
        let body = json(request.body)
        XCTAssertEqual(body["code"] as? String, "0a1b2c3d.abcdefghijklmnopqrstuvwx")
        XCTAssertEqual(body["name"] as? String, "iPhone")
        XCTAssertEqual(body["bearer"] as? Bool, true)
    }

    func testPairWithAWrongCodeGivesTheKernelSentence() async throws {
        let fake = FakeTransport(status: 403, body: #"{"error": "That code is wrong, used, or expired."}"#)
        let code = try XCTUnwrap(PairingCode("0a1b2c3d.abcdefghijklmnopqrstuvwx"))
        await assertThrows(.server(status: 403, message: "That code is wrong, used, or expired.")) {
            try await client(fake, token: nil).pair(code, name: "iPhone")
        }
    }

    func testPairWithoutATokenInTheAnswerIsUnreadable() async throws {
        let fake = FakeTransport(status: 201, body: #"{"device": {"id": "0123456789ab", "name": "iPhone"}}"#)
        let code = try XCTUnwrap(PairingCode("0a1b2c3d.abcdefghijklmnopqrstuvwx"))
        await assertThrows(.unreadable) { try await client(fake, token: nil).pair(code, name: "iPhone") }
    }

    func testPairOfflineIsOffline() async throws {
        let fake = FakeTransport([.fail])
        let code = try XCTUnwrap(PairingCode("0a1b2c3d.abcdefghijklmnopqrstuvwx"))
        await assertThrows(.offline) { try await client(fake, token: nil).pair(code, name: "iPhone") }
    }

    // MARK: Reply and press

    func testReplySendsTheBodyAndTheBearer() async throws {
        let fake = FakeTransport(status: 200, body: #"{"ok": true, "taken": true}"#)
        let answer = try await client(fake).reply(id: "r-1", text: "läst 2", answers: "m-9")
        XCTAssertEqual(answer, ReplyAnswer(taken: true))
        let request = try XCTUnwrap(fake.sent.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.path, "/api/channel/reply")
        XCTAssertEqual(request.headers["Authorization"], "Bearer tok")
        XCTAssertEqual(request.headers["Accept"], "application/json")
        let body = json(request.body)
        XCTAssertEqual(body["channel"] as? String, "app")
        XCTAssertEqual(body["id"] as? String, "r-1")
        XCTAssertEqual(body["text"] as? String, "läst 2")
        XCTAssertEqual(body["answers"] as? String, "m-9")
    }

    func testReplyWithoutAnswersSendsJSONNull() async throws {
        let fake = FakeTransport(status: 200, body: #"{"ok": true, "taken": true}"#)
        _ = try await client(fake).reply(id: "r-1", text: "hej", answers: nil)
        let body = try XCTUnwrap(fake.sent.first?.body)
        let text = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(text.contains(#""answers":null"#), text)
    }

    func testReplyNotTakenCarriesTheReason() async throws {
        let fake = FakeTransport(status: 200, body: #"{"ok": true, "taken": false, "reason": "Too many replies this hour."}"#)
        let answer = try await client(fake).reply(id: "r-1", text: "x", answers: nil)
        XCTAssertEqual(answer, ReplyAnswer(taken: false, reason: "Too many replies this hour."))
    }

    func testReplyWithOkFalseIsAServerError() async throws {
        let fake = FakeTransport(status: 200, body: #"{"ok": false, "error": "A reply needs a text and an id."}"#)
        await assertThrows(.server(status: 200, message: "A reply needs a text and an id.")) {
            try await client(fake).reply(id: "r-1", text: "", answers: nil)
        }
    }

    func testReplyWithoutATokenIsNotPairedAndSendsNothing() async throws {
        let fake = FakeTransport(status: 200, body: #"{"ok": true, "taken": true}"#)
        await assertThrows(.notPaired) { try await client(fake, token: nil).reply(id: "r", text: "x", answers: nil) }
        XCTAssertTrue(fake.sent.isEmpty)
    }

    func testPressSendsTheData() async throws {
        let fake = FakeTransport(status: 200, body: #"{"ok": true, "taken": true}"#)
        let answer = try await client(fake).press(id: "p-1", data: "lifeos-q:abc:2")
        XCTAssertTrue(answer.taken)
        let request = try XCTUnwrap(fake.sent.first)
        XCTAssertEqual(request.url.path, "/api/channel/press")
        let body = json(request.body)
        XCTAssertEqual(body["channel"] as? String, "app")
        XCTAssertEqual(body["id"] as? String, "p-1")
        XCTAssertEqual(body["data"] as? String, "lifeos-q:abc:2")
    }

    func testPressNotTaken() async throws {
        let fake = FakeTransport(status: 200, body: #"{"ok": true, "taken": false, "reason": "The question is closed."}"#)
        let answer = try await client(fake).press(id: "p-1", data: "x")
        XCTAssertEqual(answer.reason, "The question is closed.")
        XCTAssertFalse(answer.taken)
    }

    // MARK: Items

    func testItemsDecodeEveryField() async throws {
        let fake = FakeTransport(status: 200, body: """
        {"items": [
          {"id": "m-2", "at": "2026-03-04T05:06:07Z", "text": "Line one\\nLine two", "kind": "digest", "run": "run-1", "finding": null},
          {"id": "m-1", "at": "2026-03-04T05:00:00.123+01:00", "text": "Q", "kind": "question", "run": null, "finding": "f-1"}
        ], "next": "m-1"}
        """)
        let page = try await client(fake).items()
        XCTAssertEqual(page.items.map(\.id), ["m-2", "m-1"])
        XCTAssertEqual(page.next, "m-1")
        XCTAssertEqual(page.items[0].kind, .digest)
        XCTAssertEqual(page.items[0].run, "run-1")
        XCTAssertNil(page.items[0].finding)
        XCTAssertEqual(page.items[0].at, Date(timeIntervalSince1970: 1_772_600_767))
        XCTAssertEqual(page.items[1].kind, .question)
        XCTAssertEqual(page.items[1].finding, "f-1")
        XCTAssertNotNil(page.items[1].at)
        let request = try XCTUnwrap(fake.sent.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.url.path, "/api/channels/app/items")
        XCTAssertEqual(request.url.query, "limit=50")
        XCTAssertNil(request.body)
        XCTAssertNil(request.headers["Content-Type"])
    }

    func testItemsSendBeforeAndLimit() async throws {
        let fake = FakeTransport(status: 200, body: #"{"items": [], "next": null}"#)
        let page = try await client(fake).items(before: "m 1+2", limit: 10)
        XCTAssertTrue(page.items.isEmpty)
        XCTAssertNil(page.next)
        XCTAssertEqual(fake.sent.first?.url.query, "before=m%201%2B2&limit=10")
    }

    func testItemsKeepAnUnknownKindAndSkipABrokenItem() async throws {
        let fake = FakeTransport(status: 200, body: """
        {"items": [
          {"id": "m-3", "at": "not a time", "text": "new kind", "kind": "weather"},
          {"text": "no id"},
          {"id": 7, "text": "numeric id", "kind": "note"}
        ], "next": 7}
        """)
        let page = try await client(fake).items()
        XCTAssertEqual(page.items.map(\.id), ["m-3", "7"])
        XCTAssertEqual(page.items[0].kind, .other("weather"))
        XCTAssertEqual(page.items[0].kind.label, "Meddelande")
        XCTAssertNil(page.items[0].at)
        XCTAssertEqual(page.next, "7")
    }

    func testItemsWithoutAListAreUnreadable() async throws {
        let fake = FakeTransport(status: 200, body: #"{"messages": "nope"}"#)
        await assertThrows(.unreadable) { try await client(fake).items() }
    }

    func testItemsThatAreNotJSONAreUnreadable() async throws {
        let fake = FakeTransport(status: 200, body: "<html>")
        await assertThrows(.unreadable) { try await client(fake).items() }
    }

    // MARK: Terminal

    func testTerminalReadsTurns() async throws {
        let fake = FakeTransport(status: 200, body: """
        {"turns": [
          {"id": "t-2", "role": "assistant", "text": "Svar", "at": "2026-03-04T05:06:07Z", "run": "run-9", "source": "app"},
          {"id": "t-1", "role": "you", "text": "Fråga", "at": "2026-03-04T05:06:00Z", "run": null, "source": "app"}
        ], "next": null}
        """)
        let page = try await client(fake).terminal()
        XCTAssertEqual(page.items.map(\.id), ["t-2", "t-1"])
        XCTAssertEqual(page.items[0].role, .assistant)
        XCTAssertEqual(page.items[1].role, .you)
        XCTAssertEqual(page.items[0].run, "run-9")
        XCTAssertEqual(page.items[0].source, "app")
        XCTAssertNil(page.next)
        XCTAssertEqual(fake.sent.first?.url.path, "/api/terminal")
    }

    func testTerminalAcceptsMessagesAsTheListName() async throws {
        let fake = FakeTransport(status: 200, body: #"{"messages": [{"id": "t-1", "role": "you", "text": "x"}], "next": "t-1"}"#)
        let page = try await client(fake).terminal(before: "t-5", limit: 20)
        XCTAssertEqual(page.items.map(\.id), ["t-1"])
        XCTAssertEqual(page.next, "t-1")
        XCTAssertEqual(fake.sent.first?.url.query, "before=t-5&limit=20")
    }

    func testTerminalKeepsAnUnknownRole() async throws {
        let fake = FakeTransport(status: 200, body: #"{"turns": [{"id": "t-1", "role": "kernel", "text": "x"}], "next": null}"#)
        let page = try await client(fake).terminal()
        XCTAssertEqual(page.items.first?.role, .other("kernel"))
    }

    func testTerminalWithNeitherListIsUnreadable() async throws {
        let fake = FakeTransport(status: 200, body: #"{"next": null}"#)
        await assertThrows(.unreadable) { try await client(fake).terminal() }
    }

    // MARK: Push

    func testRegisterPushSendsTheToken() async throws {
        let fake = FakeTransport(status: 200, body: #"{"registered": true}"#)
        let token = String(repeating: "ab", count: 32)
        try await client(fake).registerPush(token: token)
        let request = try XCTUnwrap(fake.sent.first)
        XCTAssertEqual(request.url.path, "/api/push/register")
        XCTAssertEqual(json(request.body)["token"] as? String, token)
        XCTAssertEqual(request.headers["Authorization"], "Bearer tok")
    }

    func testRegisterPushRefusesABadTokenBeforeSending() async throws {
        let fake = FakeTransport(status: 200, body: #"{"registered": true}"#)
        for bad in ["", String(repeating: "AB", count: 32), String(repeating: "a", count: 63), String(repeating: "g", count: 64)] {
            await assertThrows(.server(status: 0, message: "The push token is not 64 hex letters.")) {
                try await client(fake).registerPush(token: bad)
            }
        }
        XCTAssertTrue(fake.sent.isEmpty)
    }

    func testRegisterPushNotRegisteredIsUnreadable() async throws {
        let fake = FakeTransport(status: 200, body: #"{"registered": false}"#)
        await assertThrows(.unreadable) { try await client(fake).registerPush(token: String(repeating: "0", count: 64)) }
    }

    func testPushTokenHex() {
        let data = Data([0x00, 0x0f, 0xa0, 0xff])
        XCTAssertEqual(PushToken.hex(data), "000fa0ff")
        XCTAssertTrue(PushToken.isValid(PushToken.hex(Data(repeating: 0xab, count: 32))))
    }

    // MARK: Errors on every route

    func testUnauthorizedIsNotPairedOnEveryRoute() async throws {
        let body = #"{"error": "Pair this device first.", "pair": true}"#
        await assertThrows(.notPaired) { try await client(FakeTransport(status: 401, body: body)).items() }
        await assertThrows(.notPaired) { try await client(FakeTransport(status: 401, body: body)).terminal() }
        await assertThrows(.notPaired) { try await client(FakeTransport(status: 401, body: body)).reply(id: "r", text: "x", answers: nil) }
        await assertThrows(.notPaired) { try await client(FakeTransport(status: 401, body: body)).press(id: "p", data: "d") }
        await assertThrows(.notPaired) {
            try await client(FakeTransport(status: 401, body: body)).registerPush(token: String(repeating: "0", count: 64))
        }
    }

    func testUnauthorizedWithoutABodyIsStillNotPaired() async throws {
        await assertThrows(.notPaired) { try await client(FakeTransport(status: 401, body: "")).items() }
    }

    func testOfflineOnEveryRoute() async throws {
        await assertThrows(.offline) { try await client(FakeTransport([.fail])).items() }
        await assertThrows(.offline) { try await client(FakeTransport([.fail])).terminal() }
        await assertThrows(.offline) { try await client(FakeTransport([.fail])).reply(id: "r", text: "x", answers: nil) }
        await assertThrows(.offline) { try await client(FakeTransport([.fail])).press(id: "p", data: "d") }
        await assertThrows(.offline) { try await client(FakeTransport([.fail])).registerPush(token: String(repeating: "0", count: 64)) }
    }

    func testServerErrorsCarryTheSentence() async throws {
        let body = #"{"error": "The body must be JSON."}"#
        await assertThrows(.server(status: 415, message: "The body must be JSON.")) {
            try await client(FakeTransport(status: 415, body: body)).reply(id: "r", text: "x", answers: nil)
        }
        await assertThrows(.server(status: 403, message: "The body must be JSON.")) {
            try await client(FakeTransport(status: 403, body: body)).items()
        }
        await assertThrows(.server(status: 500, message: "")) {
            try await client(FakeTransport(status: 500, body: "Internal error")).terminal()
        }
    }

    func testRetryableErrors() {
        XCTAssertTrue(ClientError.offline.isRetryable)
        XCTAssertTrue(ClientError.server(status: 503, message: "").isRetryable)
        XCTAssertFalse(ClientError.server(status: 400, message: "").isRetryable)
        XCTAssertFalse(ClientError.notPaired.isRetryable)
        XCTAssertFalse(ClientError.unreadable.isRetryable)
    }

    // MARK: URLs

    func testAKernelWithAPathPrefixKeepsIt() {
        let prefixed = Client(kernel: URL(string: "https://box.example.invalid/lifeos")!, token: "t", transport: FakeTransport([]))
        XCTAssertEqual(prefixed.url("api/terminal").absoluteString, "https://box.example.invalid/lifeos/api/terminal")
        let port = Client(kernel: URL(string: "https://box.example.invalid:8446")!, token: "t", transport: FakeTransport([]))
        XCTAssertEqual(port.url("api/pair").absoluteString, "https://box.example.invalid:8446/api/pair")
    }

    func testWithTokenKeepsTheKernel() {
        let base = client(FakeTransport([]), token: nil)
        let paired = base.with(token: "new")
        XCTAssertEqual(paired.token, "new")
        XCTAssertEqual(paired.kernel, kernelURL)
    }
}
