import Foundation
import XCTest
@testable import LifeOSKit

final class DisplayTests: XCTestCase {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "sv_SE")
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }

    func date(_ text: String) -> Date { KernelTime.parse(text)! }

    func testRowTimes() {
        let now = date("2026-03-04T12:00:00+01:00")  // a Wednesday
        XCTAssertEqual(RowTime.text(for: date("2026-03-04T08:05:00+01:00"), now: now, calendar: calendar), "08:05")
        XCTAssertEqual(RowTime.text(for: date("2026-03-03T23:59:00+01:00"), now: now, calendar: calendar), "igår")
        XCTAssertEqual(RowTime.text(for: date("2026-03-01T10:00:00+01:00"), now: now, calendar: calendar), "söndag")
        // CLDR versions differ on the abbreviation dot, so only the start is checked.
        XCTAssertTrue(RowTime.text(for: date("2026-02-20T10:00:00+01:00"), now: now, calendar: calendar).hasPrefix("20 feb"))
        let lastYear = RowTime.text(for: date("2025-12-24T10:00:00+01:00"), now: now, calendar: calendar)
        XCTAssertTrue(lastYear.hasPrefix("24 dec") && lastYear.hasSuffix("2025"), lastYear)
        XCTAssertEqual(RowTime.text(for: nil, now: now, calendar: calendar), "")
    }

    func testFullTime() {
        XCTAssertEqual(RowTime.full(for: date("2026-03-04T14:05:00+01:00"), calendar: calendar), "4 mars 2026 kl. 14:05")
        XCTAssertEqual(RowTime.full(for: nil, calendar: calendar), "")
    }

    func testPlainTextHasNoLinks() {
        XCTAssertEqual(LinkText.segments("Inga länkar här."), [.text("Inga länkar här.")])
        XCTAssertEqual(LinkText.segments(""), [])
    }

    func testANumberedItemLine() {
        let segments = LinkText.segments("1. Release notes: https://example.com/a?b=1.\n2. Other")
        XCTAssertEqual(segments, [
            .text("1. Release notes: "),
            .link("https://example.com/a?b=1", URL(string: "https://example.com/a?b=1")!),
            .text(".\n2. Other"),
        ])
    }

    func testParenthesesAroundAndInsideALink() {
        XCTAssertEqual(LinkText.segments("(se https://example.com/x)"), [
            .text("(se "), .link("https://example.com/x", URL(string: "https://example.com/x")!), .text(")"),
        ])
        let wiki = "https://example.com/wiki/Foo_(bar)"
        XCTAssertEqual(LinkText.segments("Läs \(wiki)."), [
            .text("Läs "), .link(wiki, URL(string: wiki)!), .text("."),
        ])
    }

    func testTwoLinksAndPlainHTTP() {
        let segments = LinkText.segments("http://a.example b https://b.example/")
        XCTAssertEqual(segments.count, 3)
        guard case .link(_, let first) = segments[0], case .link(_, let second) = segments[2] else {
            return XCTFail("Expected two links.")
        }
        XCTAssertEqual(first.host, "a.example")
        XCTAssertEqual(second.host, "b.example")
    }

    func testABareSchemeIsText() {
        XCTAssertEqual(LinkText.segments("see https:// now"), [.text("see https:// now")])
    }

    func testOtherSchemesStayText() {
        XCTAssertEqual(LinkText.segments("javascript:alert(1) ftp://x.example"), [.text("javascript:alert(1) ftp://x.example")])
    }
}
