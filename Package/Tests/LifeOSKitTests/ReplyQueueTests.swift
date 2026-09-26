import Foundation
import XCTest
@testable import LifeOSKit

final class ReplyQueueTests: XCTestCase {
    func testEnqueueWritesToDiskBeforeSending() async throws {
        let directory = temporaryDirectory()
        let queue = ReplyQueue(directory: directory)
        let reply = try await queue.enqueue(text: "  läst 2 \n", answers: "m-1")
        XCTAssertEqual(reply.text, "läst 2")
        XCTAssertEqual(reply.state, .unsent)
        XCTAssertEqual(reply.id, reply.id.lowercased())
        XCTAssertNotNil(UUID(uuidString: reply.id))
        let reopened = ReplyQueue(directory: directory)
        let unsent = await reopened.unsent
        XCTAssertEqual(unsent, [reply])
    }

    func testAnUnsentReplyIsResentOnTheNextLaunchWithTheSameId() async throws {
        let directory = temporaryDirectory()
        let first = ReplyQueue(directory: directory)
        let reply = try await first.enqueue(text: "läst 2", answers: "m-1")
        let offline = FakeTransport([.fail])
        let stop = await first.flush(using: client(offline))
        XCTAssertEqual(stop, .offline)
        let afterOffline = await first.all
        XCTAssertEqual(afterOffline.first?.state, .unsent)
        XCTAssertEqual(afterOffline.first?.attempts, 1)

        // The next launch reads the file and sends again.
        let second = ReplyQueue(directory: directory)
        let online = FakeTransport(status: 200, body: #"{"ok": true, "taken": true}"#)
        let none = await second.flush(using: client(online))
        XCTAssertNil(none)
        let sentBody = json(online.sent.first?.body)
        XCTAssertEqual(sentBody["id"] as? String, reply.id)
        XCTAssertEqual(sentBody["answers"] as? String, "m-1")
        XCTAssertEqual(json(offline.sent.first?.body)["id"] as? String, reply.id)
        let settled = await ReplyQueue(directory: directory).all
        XCTAssertEqual(settled.first?.state, .sent)
        XCTAssertEqual(settled.first?.attempts, 2)
    }

    func testRepliesGoInOrderAndStopAtTheFirstOffline() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        let a = try await queue.enqueue(text: "a", answers: nil)
        let b = try await queue.enqueue(text: "b", answers: nil)
        let c = try await queue.enqueue(text: "c", answers: nil)
        let fake = FakeTransport([.answer(200, #"{"ok": true, "taken": true}"#), .fail])
        let stop = await queue.flush(using: client(fake))
        XCTAssertEqual(stop, .offline)
        XCTAssertEqual(fake.sent.map { json($0.body)["id"] as? String }, [a.id, b.id])
        let states = await queue.all.map(\.state)
        XCTAssertEqual(states, [.sent, .unsent, .unsent])
        let left = await queue.unsent.map(\.id)
        XCTAssertEqual(left, [b.id, c.id])
    }

    func testANotTakenReplyIsRefusedWithTheReason() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        try await queue.enqueue(text: "x", answers: nil)
        let fake = FakeTransport(status: 200, body: #"{"ok": true, "taken": false, "reason": "Too many replies."}"#)
        await queue.flush(using: client(fake))
        let reply = await queue.all.first
        XCTAssertEqual(reply?.state, .refused)
        XCTAssertEqual(reply?.reason, "Too many replies.")
    }

    func testAReplyToAClosedMessageIsRefusedWithTheKernelSentence() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        try await queue.enqueue(text: "läst 2", answers: "m-old")
        let fake = FakeTransport(status: 200, body: #"{"ok": true, "taken": false, "reason": "Meddelandet går inte längre att svara på."}"#)
        let stop = await queue.flush(using: client(fake))
        XCTAssertNil(stop)
        let reply = await queue.all.first
        XCTAssertEqual(reply?.state, .refused)
        XCTAssertEqual(reply?.reason, "Meddelandet går inte längre att svara på.")
        let unsent = await queue.unsent
        XCTAssertTrue(unsent.isEmpty)
    }

    func testEmptyAndOversizedRepliesNeverEnterTheQueue() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        do {
            try await queue.enqueue(text: "  \n ", answers: nil)
            XCTFail("An empty reply was queued.")
        } catch {
            XCTAssertEqual(error as? ClientError, .invalid("The reply is empty."))
        }
        do {
            try await queue.enqueue(text: String(repeating: "a", count: Client.maxTextBytes + 1), answers: nil)
            XCTFail("An oversized reply was queued.")
        } catch {
            XCTAssertEqual(error as? ClientError, .invalid("The text is longer than 64 KiB."))
        }
        let all = await queue.all
        XCTAssertTrue(all.isEmpty)
    }

    func testAnInvalidReplyInTheFileIsRefusedWithTheWords() async throws {
        let directory = temporaryDirectory()
        let bad = OutboundReply(id: "short", text: "x", answers: nil)
        try JSONFile<[OutboundReply]>(directory: directory, name: "replies.json").save([bad])
        let queue = ReplyQueue(directory: directory)
        let fake = FakeTransport([])
        await queue.flush(using: client(fake))
        let reply = await queue.all.first
        XCTAssertEqual(reply?.state, .refused)
        XCTAssertEqual(reply?.reason, "A reply id is 8 to 64 letters, digits, or hyphens.")
        XCTAssertTrue(fake.sent.isEmpty)
    }

    func testAFourHundredRefusesAndTheNextReplyStillGoes() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        try await queue.enqueue(text: "bad", answers: nil)
        try await queue.enqueue(text: "good", answers: nil)
        let fake = FakeTransport([
            .answer(400, #"{"error": "A reply needs a text and an id."}"#),
            .answer(200, #"{"ok": true, "taken": true}"#),
        ])
        let stop = await queue.flush(using: client(fake))
        XCTAssertNil(stop)
        let all = await queue.all
        XCTAssertEqual(all.map(\.state), [.refused, .sent])
        XCTAssertEqual(all[0].reason, "A reply needs a text and an id.")
    }

    func testAFiveHundredKeepsTheReplyUnsent() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        try await queue.enqueue(text: "x", answers: nil)
        let fake = FakeTransport(status: 503, body: #"{"error": "Busy."}"#)
        let stop = await queue.flush(using: client(fake))
        XCTAssertEqual(stop, .server(status: 503, message: "Busy."))
        let state = await queue.all.first?.state
        XCTAssertEqual(state, .unsent)
    }

    func testNotPairedStopsAndKeepsTheReply() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        try await queue.enqueue(text: "x", answers: nil)
        let fake = FakeTransport(status: 401, body: #"{"error": "Pair first.", "pair": true}"#)
        let stop = await queue.flush(using: client(fake))
        XCTAssertEqual(stop, .notPaired)
        let state = await queue.all.first?.state
        XCTAssertEqual(state, .unsent)
    }

    func testAnUnreadableAnswerRefusesInsteadOfLooping() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        try await queue.enqueue(text: "x", answers: nil)
        let fake = FakeTransport(status: 200, body: "<html>")
        let stop = await queue.flush(using: client(fake))
        XCTAssertNil(stop)
        let state = await queue.all.first?.state
        XCTAssertEqual(state, .refused)
    }

    func testASentReplyIsNeverSentAgain() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        try await queue.enqueue(text: "x", answers: nil)
        let fake = FakeTransport([.answer(200, #"{"ok": true, "taken": true}"#), .answer(200, #"{"ok": true, "taken": true}"#)])
        await queue.flush(using: client(fake))
        await queue.flush(using: client(fake))
        XCTAssertEqual(fake.sent.count, 1)
    }

    func testAReplyAddedDuringAFlushGoesInTheSameFlush() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        try await queue.enqueue(text: "first", answers: nil)
        var sent: [String] = []
        await queue.flush { reply in
            sent.append(reply.text)
            if reply.text == "first" {
                try await queue.enqueue(text: "second", answers: nil)
            }
            return ReplyAnswer(taken: true)
        }
        XCTAssertEqual(sent, ["first", "second"])
    }

    func testASecondFlushWhileOneRunsSendsNothingTwice() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        try await queue.enqueue(text: "x", answers: nil)
        let gate = Gate()
        let counter = Recorder()
        let first = Task {
            await queue.flush { reply in
                await counter.add(reply.id)
                await gate.wait()
                return ReplyAnswer(taken: true)
            }
        }
        // Let the first flush reach the network.
        while await counter.values.isEmpty { await Task.yield() }
        let second = await queue.flush { reply in
            await counter.add(reply.id)
            return ReplyAnswer(taken: true)
        }
        XCTAssertNil(second)
        await gate.open()
        _ = await first.value
        let count = await counter.values.count
        XCTAssertEqual(count, 1)
    }

    func testSettledRepliesArePruned() async throws {
        let queue = ReplyQueue(directory: temporaryDirectory())
        for n in 0..<(ReplyQueue.keepSettled + 5) {
            try await queue.enqueue(text: "r\(n)", answers: nil)
        }
        await queue.flush { _ in ReplyAnswer(taken: true) }
        let all = await queue.all
        XCTAssertEqual(all.count, ReplyQueue.keepSettled)
        XCTAssertEqual(all.first?.text, "r5")
    }

    func testDiscardAndClear() async throws {
        let directory = temporaryDirectory()
        let queue = ReplyQueue(directory: directory)
        let a = try await queue.enqueue(text: "a", answers: nil)
        try await queue.enqueue(text: "b", answers: nil)
        try await queue.discard(id: a.id)
        let texts = await queue.all.map(\.text)
        XCTAssertEqual(texts, ["b"])
        await queue.clear()
        let empty = await ReplyQueue(directory: directory).all
        XCTAssertTrue(empty.isEmpty)
    }

    func testABrokenFileStartsAnEmptyQueue() async throws {
        let directory = temporaryDirectory()
        try Data("not json".utf8).write(to: directory.appendingPathComponent("replies.json"))
        let queue = ReplyQueue(directory: directory)
        let all = await queue.all
        XCTAssertTrue(all.isEmpty)
        try await queue.enqueue(text: "x", answers: nil)
        let reopened = await ReplyQueue(directory: directory).all
        XCTAssertEqual(reopened.count, 1)
    }
}

actor Gate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}
