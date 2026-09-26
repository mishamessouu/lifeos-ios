import Foundation
import XCTest
@testable import LifeOSKit

final class ReplyRuleTests: XCTestCase {
    let now = KernelTime.parse("2026-03-04T12:00:00Z")!

    func sent(_ kind: Kind, minutesAgo: Double?) -> SentMessage {
        let at = minutesAgo.map { KernelTime.format(now.addingTimeInterval(-$0 * 60)) }
        return SentMessage(id: "m-1", at: at, text: "x", kind: kind)
    }

    func testRecentMessagesOfTheFourKindsBind() {
        for kind in [Kind.finding, .digest, .question, .answer] {
            XCTAssertEqual(ReplyRule.answers(sent(kind, minutesAgo: 5), now: now), "m-1", kind.rawValue)
            XCTAssertEqual(ReplyRule.answers(sent(kind, minutesAgo: 59.9), now: now), "m-1", kind.rawValue)
        }
    }

    func testOldMessagesGoToTheTerminal() {
        XCTAssertNil(ReplyRule.answers(sent(.finding, minutesAgo: 60), now: now))
        XCTAssertNil(ReplyRule.answers(sent(.digest, minutesAgo: 600), now: now))
    }

    func testOtherKindsGoToTheTerminal() {
        for kind in [Kind.note, .notice, .other("x")] {
            XCTAssertNil(ReplyRule.answers(sent(kind, minutesAgo: 1), now: now), kind.rawValue)
        }
    }

    func testAMessageWithoutATimeGoesToTheTerminal() {
        XCTAssertNil(ReplyRule.answers(sent(.finding, minutesAgo: nil), now: now))
    }

    func testAClockALittleAheadStillBinds() {
        XCTAssertEqual(ReplyRule.answers(sent(.question, minutesAgo: -0.5), now: now), "m-1")
        XCTAssertNil(ReplyRule.answers(sent(.question, minutesAgo: -10), now: now))
    }
}
