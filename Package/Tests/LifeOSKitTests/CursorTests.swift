import Foundation
import XCTest
@testable import LifeOSKit

final class CursorTests: XCTestCase {
    func ids(_ list: CursorList<SentMessage>) -> [String] { list.items.map(\.id) }

    func page(_ ids: [String], next: String?) -> Page<SentMessage> {
        Page(items: ids.map { message($0) }, next: next)
    }

    func testTheFirstPageFillsAnEmptyList() {
        var list = CursorList<SentMessage>()
        list.mergeNewest(page(["5", "4", "3"], next: "3"))
        XCTAssertEqual(ids(list), ["5", "4", "3"])
        XCTAssertEqual(list.next, "3")
        XCTAssertTrue(list.hasMore)
        XCTAssertEqual(list.newestID, "5")
    }

    func testAShortFirstPageEndsTheList() {
        var list = CursorList<SentMessage>()
        list.mergeNewest(page(["2", "1"], next: nil))
        XCTAssertFalse(list.hasMore)
    }

    func testNewItemsGoOnTopAndTheCursorStays() {
        var list = CursorList(items: [message("5"), message("4"), message("3")], next: "3")
        list.mergeNewest(page(["7", "6", "5"], next: "5"))
        XCTAssertEqual(ids(list), ["7", "6", "5", "4", "3"])
        XCTAssertEqual(list.next, "3")
    }

    func testANewerCopyReplacesTheHeldOne() {
        var list = CursorList(items: [message("5", "old"), message("4")], next: "4")
        list.mergeNewest(Page(items: [message("6"), message("5", "new")], next: "5"))
        XCTAssertEqual(ids(list), ["6", "5", "4"])
        XCTAssertEqual(list.items[1].text, "new")
    }

    func testALateSettledMessageBelowAHeldOneIsKept() {
        var list = CursorList(items: [message("b")], next: nil)
        list.mergeNewest(page(["b", "a"], next: nil))
        XCTAssertEqual(ids(list), ["b", "a"])
    }

    func testLateMessagesKeepTheirPlaceAmongHeldOnes() {
        // Held c, b, a. The kernel now also lists x between c and b, and y at the top.
        var list = CursorList(items: [message("c"), message("b"), message("a")], next: "a")
        list.mergeNewest(page(["y", "c", "x", "b"], next: "b"))
        XCTAssertEqual(ids(list), ["y", "c", "x", "b", "a"])
        XCTAssertEqual(list.next, "a")
    }

    func testHeldItemsThePageSkipsStayAfterWhatTheyFollowed() {
        var list = CursorList(items: [message("c"), message("b"), message("a")], next: nil)
        list.mergeNewest(page(["d", "c", "a"], next: nil))
        XCTAssertEqual(ids(list), ["d", "c", "b", "a"])
    }

    func testAnEmptyPageKeepsTheHeldItems() {
        var list = CursorList(items: [message("2"), message("1")], next: "1")
        XCTAssertTrue(list.joins(page([], next: nil)))
        list.mergeNewest(page([], next: nil))
        XCTAssertEqual(ids(list), ["2", "1"])
        XCTAssertEqual(list.next, "1")
    }

    func testAnEmptyPageOnAnEmptyListStaysEmpty() {
        var list = CursorList<SentMessage>()
        list.mergeNewest(page([], next: nil))
        XCTAssertTrue(list.items.isEmpty)
        XCTAssertFalse(list.hasMore)
    }

    func testDuplicatesInAPageAreDropped() {
        var list = CursorList<SentMessage>()
        list.mergeNewest(page(["3", "3", "2", "1", "2"], next: nil))
        XCTAssertEqual(ids(list), ["3", "2", "1"])
    }

    func testAPageThatDoesNotJoinStartsOver() {
        var list = CursorList(items: [message("2"), message("1")], next: nil)
        let fresh = page(["9", "8"], next: "8")
        XCTAssertFalse(list.joins(fresh))
        list.mergeNewest(fresh)
        XCTAssertEqual(ids(list), ["9", "8"])
        XCTAssertEqual(list.next, "8")
    }

    func testAWholeListThatDoesNotMeetReplaces() {
        var list = CursorList(items: [message("old")], next: nil)
        let whole = page(["b", "a"], next: nil)
        XCTAssertTrue(list.joins(whole))
        list.mergeNewest(whole)
        XCTAssertEqual(ids(list), ["b", "a"])
        XCTAssertFalse(list.hasMore)
    }

    func testSeveralPagesJoinUp() {
        var list = CursorList(items: [message("3"), message("2")], next: "2")
        list.mergeNewest([page(["7", "6"], next: "6"), page(["5", "4"], next: "4"), page(["3", "2"], next: "2")])
        XCTAssertEqual(ids(list), ["7", "6", "5", "4", "3", "2"])
        XCTAssertEqual(list.next, "2")
    }

    func testOlderPagesAppendWithoutDuplicates() {
        var list = CursorList(items: [message("5"), message("4")], next: "4")
        list.appendOlder(page(["4", "3", "2"], next: "2"))
        XCTAssertEqual(ids(list), ["5", "4", "3", "2"])
        XCTAssertEqual(list.next, "2")
        list.appendOlder(page(["1"], next: nil))
        XCTAssertEqual(ids(list), ["5", "4", "3", "2", "1"])
        XCTAssertFalse(list.hasMore)
    }

    func testAnEmptyMergeChangesNothing() {
        var list = CursorList(items: [message("1")], next: nil)
        list.mergeNewest([])
        XCTAssertEqual(ids(list), ["1"])
    }

    func testTrimKeepsTheNewestAndMovesTheCursor() {
        let list = CursorList(items: (1...10).reversed().map { message(String($0)) }, next: nil)
        let trimmed = list.trimmed(to: 3)
        XCTAssertEqual(ids(trimmed), ["10", "9", "8"])
        XCTAssertEqual(trimmed.next, "8")
        XCTAssertEqual(list.trimmed(to: 20), list)
    }

    func testTheListRoundTripsThroughJSON() throws {
        let list = CursorList(items: [message("2"), SentMessage(id: "1", at: nil, text: "x", kind: .other("new"))], next: "1")
        let data = try JSONEncoder().encode(list)
        XCTAssertEqual(try JSONDecoder().decode(CursorList<SentMessage>.self, from: data), list)
    }

    // MARK: The loader

    func testTheLoaderFetchesUntilItJoins() async throws {
        let held = CursorList(items: [message("3"), message("2")], next: "2")
        let pages: [String?: Page<SentMessage>] = [
            nil: page(["7", "6"], next: "6"),
            "6": page(["5", "4"], next: "4"),
            "4": page(["3", "2"], next: "2"),
        ]
        let asked = Recorder()
        let merged = try await NewestLoader.refresh(held, limit: 2) { before, limit in
            await asked.add(before)
            XCTAssertEqual(limit, 2)
            return pages[before]!
        }
        XCTAssertEqual(ids(merged), ["7", "6", "5", "4", "3", "2"])
        let seen = await asked.values
        XCTAssertEqual(seen, [nil, "6", "4"])
    }

    func testTheLoaderStopsAfterOnePageWhenItJoins() async throws {
        let held = CursorList(items: [message("3")], next: nil)
        let asked = Recorder()
        let merged = try await NewestLoader.refresh(held) { before, _ in
            await asked.add(before)
            return self.page(["4", "3"], next: "3")
        }
        XCTAssertEqual(ids(merged), ["4", "3"])
        let count = await asked.values.count
        XCTAssertEqual(count, 1)
    }

    func testTheLoaderGivesUpAfterMaxPagesAndStartsOver() async throws {
        let held = CursorList(items: [message("old")], next: nil)
        let asked = Recorder()
        let merged = try await NewestLoader.refresh(held, limit: 1) { before, _ in
            await asked.add(before)
            let n = await asked.values.count
            return self.page(["p\(n)"], next: "p\(n)")
        }
        let count = await asked.values.count
        XCTAssertEqual(count, NewestLoader.maxPages)
        XCTAssertEqual(ids(merged), ["p1", "p2", "p3", "p4", "p5"])
        XCTAssertEqual(merged.next, "p5")
    }

    func testTheLoaderPassesErrorsOn() async {
        let held = CursorList<SentMessage>()
        do {
            _ = try await NewestLoader.refresh(held) { _, _ in throw ClientError.offline }
            XCTFail("Expected offline.")
        } catch {
            XCTAssertEqual(error as? ClientError, .offline)
        }
    }

    func testTerminalTurnsUseTheSameList() {
        var list = CursorList<TerminalTurn>()
        list.mergeNewest(Page(items: [TerminalTurn(id: "t-2", role: .assistant, text: "b", at: nil),
                                      TerminalTurn(id: "t-1", role: .you, text: "a", at: nil)], next: nil))
        XCTAssertEqual(list.items.map(\.id), ["t-2", "t-1"])
    }
}

actor Recorder {
    private(set) var values: [String?] = []
    func add(_ value: String?) { values.append(value) }
}
