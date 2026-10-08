import Foundation
import XCTest
@testable import LifeOSKit

@MainActor
final class CachedStateTests: XCTestCase {
    private let paired = Credentials(kernel: kernelURL, token: "tok", deviceID: "0123456789ab", deviceName: "iPhone")
    private let turn = TerminalTurn(id: "t-1", role: .you, text: "a", at: nil)

    /// A directory as a paired phone leaves it: credentials, a message, a
    /// Terminal turn, and one unsent reply.
    private func pairedPhone() async throws -> (URL, SwitchKeychain, OutboundReply) {
        let directory = temporaryDirectory()
        let keychain = SwitchKeychain()
        let state = CachedState(directory: directory, keychain: keychain)
        try await state.pair(paired)
        state.save(messages: CursorList(items: [message("m-1")]), keeping: 200)
        state.save(turns: CursorList(items: [turn]), keeping: 200)
        let reply = try await state.queue.enqueue(text: "läst 2", answers: nil)
        return (directory, keychain, reply)
    }

    private func names(in directory: URL) throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
    }

    func testALaunchWithCredentialsRestoresTheFiles() async throws {
        let (directory, keychain, reply) = try await pairedPhone()
        let state = CachedState(directory: directory, keychain: keychain)
        XCTAssertEqual(state.launch, .paired(paired, messages: CursorList(items: [message("m-1")]), turns: CursorList(items: [turn])))
        XCTAssertFalse(state.waiting)
        let readAgain = await state.readAgain()
        XCTAssertNil(readAgain)
        let unsent = await state.queue.unsent
        XCTAssertEqual(unsent, [reply])
    }

    func testALaunchWithNoTokenDeletesTheFiles() async throws {
        let (directory, keychain, _) = try await pairedPhone()
        try keychain.delete(CredentialStore.key)
        let state = CachedState(directory: directory, keychain: keychain)
        XCTAssertEqual(state.launch, .unpaired)
        XCTAssertEqual(try names(in: directory), [])
        let all = await state.queue.all
        XCTAssertTrue(all.isEmpty)
    }

    func testALockedLaunchKeepsTheFilesAndRestoresThemAfterUnlock() async throws {
        let (directory, keychain, reply) = try await pairedPhone()
        keychain.locked = true
        let url = directory.appendingPathComponent(ReplyQueue.fileName)
        try refuseReads(url)
        let state = CachedState(directory: directory, keychain: keychain)
        XCTAssertEqual(state.launch, .waiting)
        XCTAssertTrue(state.waiting)
        XCTAssertEqual(try names(in: directory), ["messages.json", "terminal.json", "replies.json"])
        let stillLocked = await state.readAgain()
        XCTAssertEqual(stillLocked, .waiting)

        keychain.locked = false
        try allowReads(url)
        let restored = await state.readAgain()
        XCTAssertEqual(restored, .paired(paired, messages: CursorList(items: [message("m-1")]), turns: CursorList(items: [turn])))
        XCTAssertFalse(state.waiting)
        let unsent = await state.queue.unsent
        XCTAssertEqual(unsent, [reply])
        // The launch work (push registration) runs once: no second result.
        let again = await state.readAgain()
        XCTAssertNil(again)

        // The first flush after unlock sends the reply from before the lock.
        let online = FakeTransport(status: 200, body: #"{"ok": true, "taken": true}"#)
        await state.queue.flush(using: client(online))
        XCTAssertEqual(online.sent.map { json($0.body)["id"] as? String }, [reply.id])
    }

    func testALockedLaunchThatFindsNoTokenLaterDeletesTheFiles() async throws {
        let (directory, keychain, _) = try await pairedPhone()
        keychain.locked = true
        let state = CachedState(directory: directory, keychain: keychain)
        XCTAssertEqual(state.launch, .waiting)
        keychain.locked = false
        try keychain.delete(CredentialStore.key)
        let read = await state.readAgain()
        XCTAssertEqual(read, .unpaired)
        XCTAssertEqual(try names(in: directory), [])
        let all = await state.queue.all
        XCTAssertTrue(all.isEmpty)
    }

    func testPairingWhileTheReadIsRefusedDropsTheOldFiles() async throws {
        let (directory, keychain, _) = try await pairedPhone()
        keychain.locked = true
        let state = CachedState(directory: directory, keychain: keychain)
        XCTAssertEqual(state.launch, .waiting)
        let other = Credentials(kernel: kernelURL, token: "new", deviceID: "ba9876543210", deviceName: "iPhone")
        try await state.pair(other)
        XCTAssertFalse(state.waiting)
        XCTAssertEqual(try names(in: directory), [])
        let all = await state.queue.all
        XCTAssertTrue(all.isEmpty)
        keychain.locked = false
        XCTAssertEqual(CachedState(directory: directory, keychain: keychain).launch,
                       .paired(other, messages: CursorList(), turns: CursorList()))
    }

    func testAFailedPairingSaveKeepsTheFiles() async throws {
        let (directory, _, _) = try await pairedPhone()
        let state = CachedState(directory: directory, keychain: LockedEverything())
        XCTAssertEqual(state.launch, .waiting)
        do {
            try await state.pair(paired)
            XCTFail("The save should fail.")
        } catch {}
        XCTAssertTrue(state.waiting)
        XCTAssertEqual(try names(in: directory), ["messages.json", "terminal.json", "replies.json"])
    }

    func testForgetDropsTheTokenAndTheFiles() async throws {
        let (directory, keychain, _) = try await pairedPhone()
        let state = CachedState(directory: directory, keychain: keychain)
        await state.forget()
        XCTAssertEqual(try names(in: directory), [])
        XCTAssertNil(try keychain.read(CredentialStore.key))
    }
}

/// A Keychain that refuses every call.
private struct LockedEverything: KeychainStore {
    struct Locked: Error {}
    func read(_ key: String) throws -> Data? { throw Locked() }
    func write(_ data: Data, for key: String) throws { throw Locked() }
    func delete(_ key: String) throws { throw Locked() }
}
