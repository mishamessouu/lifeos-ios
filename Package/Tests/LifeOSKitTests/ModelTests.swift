import Foundation
import XCTest
@testable import LifeOSKit

final class ModelTests: XCTestCase {
    func testEveryKindHasASwedishLabelAndASymbol() {
        let kinds: [Kind] = [.finding, .digest, .question, .answer, .note, .notice, .other("x")]
        XCTAssertEqual(kinds.map(\.label), ["Fynd", "Dagens fokus", "Fråga", "Svar", "Notis", "Varning", "Meddelande"])
        XCTAssertTrue(kinds.allSatisfy { !$0.symbol.isEmpty })
        for kind in kinds {
            XCTAssertEqual(Kind(rawValue: kind.rawValue), kind)
        }
    }

    func testAMessageRoundTripsThroughTheCache() throws {
        let original = SentMessage(id: "m-1", at: "2026-01-02T03:04:05.5Z", text: "a\nb", kind: .other("weather"), run: "r", finding: "f")
        let data = try JSONEncoder().encode(original)
        let copy = try JSONDecoder().decode(SentMessage.self, from: data)
        XCTAssertEqual(copy, original)
        XCTAssertNotNil(copy.at)
    }

    func testATurnRoundTrips() throws {
        let original = TerminalTurn(id: "t", role: .other("kernel"), text: "x", at: nil, run: nil, source: "app")
        let copy = try JSONDecoder().decode(TerminalTurn.self, from: try JSONEncoder().encode(original))
        XCTAssertEqual(copy, original)
    }

    func testPreviewTakesTheFirstLines() {
        let item = SentMessage(id: "1", at: nil, text: "\nOne\n\n  Two  \nThree\nFour", kind: .digest)
        XCTAssertEqual(item.preview(), "One\nTwo\nThree")
        XCTAssertEqual(item.preview(lines: 1), "One")
        XCTAssertEqual(item.title, "One")
        XCTAssertEqual(item.rest(), "Two\nThree")
        XCTAssertEqual(item.rest(lines: 5), "Two\nThree\nFour")
        let empty = SentMessage(id: "2", at: nil, text: " \n ", kind: .note)
        XCTAssertEqual(empty.title, "")
        XCTAssertEqual(empty.rest(), "")
    }

    func testTimesWithAndWithoutFractions() {
        XCTAssertEqual(KernelTime.parse("2026-01-01T00:00:00Z"), Date(timeIntervalSince1970: 1_767_225_600))
        XCTAssertEqual(KernelTime.parse("2026-01-01T01:00:00+01:00"), Date(timeIntervalSince1970: 1_767_225_600))
        let fractional = KernelTime.parse("2026-01-01T00:00:00.250Z")
        XCTAssertEqual(fractional?.timeIntervalSince1970 ?? 0, 1_767_225_600.25, accuracy: 0.001)
        XCTAssertNil(KernelTime.parse("yesterday"))
        XCTAssertNil(KernelTime.parse(nil))
        XCTAssertNil(KernelTime.parse(""))
        let now = Date(timeIntervalSince1970: 1_767_225_600.5)
        XCTAssertEqual(KernelTime.parse(KernelTime.format(now)), now)
    }

    func testAMissingKindOrTextStillDecodes() throws {
        let item = try JSONDecoder().decode(SentMessage.self, from: Data(#"{"id": "1"}"#.utf8))
        XCTAssertEqual(item.text, "")
        XCTAssertEqual(item.kind, .other(""))
    }
}
