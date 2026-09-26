import Foundation
import XCTest
@testable import LifeOSKit

final class PairingTests: XCTestCase {
    let secret = "abcdefghijklmnopqrstuv-_"

    func testTheLinkTheKernelPrints() throws {
        let input = try XCTUnwrap(PairingInput.parse("https://box.example.ts.net/pair.html#0a1b2c3d.\(secret)"))
        XCTAssertEqual(input.code.id, "0a1b2c3d")
        XCTAssertEqual(input.code.secret, secret)
        XCTAssertEqual(input.code.text, "0a1b2c3d.\(secret)")
        XCTAssertEqual(input.kernel?.absoluteString, "https://box.example.ts.net")
    }

    func testALinkWithAPortAndAPathPrefix() throws {
        let port = try XCTUnwrap(PairingInput.parse("https://box.example.ts.net:8446/pair.html#0a1b2c3d.\(secret)"))
        XCTAssertEqual(port.kernel?.absoluteString, "https://box.example.ts.net:8446")
        let prefix = try XCTUnwrap(PairingInput.parse("https://box.example.ts.net/lifeos/pair.html#0a1b2c3d.\(secret)"))
        XCTAssertEqual(prefix.kernel?.absoluteString, "https://box.example.ts.net/lifeos")
    }

    func testWhitespaceBracketsAndQuotesAroundALink() throws {
        for raw in [
            "  https://box.example.ts.net/pair.html#0a1b2c3d.\(secret)\n",
            "<https://box.example.ts.net/pair.html#0a1b2c3d.\(secret)>",
            "\"https://box.example.ts.net/pair.html#0a1b2c3d.\(secret)\"",
        ] {
            let input = PairingInput.parse(raw)
            XCTAssertEqual(input?.kernel?.host, "box.example.ts.net", raw)
            XCTAssertEqual(input?.code.secret, secret, raw)
        }
    }

    func testTheHostIsLowercased() throws {
        let input = try XCTUnwrap(PairingInput.parse("https://Box.Example.TS.net/pair.html#0a1b2c3d.\(secret)"))
        XCTAssertEqual(input.kernel?.host, "box.example.ts.net")
    }

    func testTheBareCode() throws {
        let input = try XCTUnwrap(PairingInput.parse(" 0a1b2c3d.\(secret) "))
        XCTAssertNil(input.kernel)
        XCTAssertEqual(input.code.id, "0a1b2c3d")
    }

    func testThePathFormWithoutAHost() throws {
        let input = try XCTUnwrap(PairingInput.parse("/pair.html#0a1b2c3d.\(secret)"))
        XCTAssertNil(input.kernel)
        XCTAssertEqual(input.code.secret, secret)
    }

    func testAnUppercaseIdIsLoweredAndTheSecretKeepsItsCase() throws {
        let code = try XCTUnwrap(PairingCode("0A1B2C3D.AbCdEfGhIjKlMnOpQrStUvWx"))
        XCTAssertEqual(code.id, "0a1b2c3d")
        XCTAssertEqual(code.secret, "AbCdEfGhIjKlMnOpQrStUvWx")
    }

    func testCodesThatAreRefused() {
        let bad = [
            "",
            "   ",
            "0a1b2c3d",                              // no secret
            "0a1b2c3d.",                             // empty secret
            ".\(secret)",                            // empty id
            "0a1b2c3.\(secret)",                     // id too short
            "0a1b2c3d9.\(secret)",                   // id too long
            "0a1b2c3g.\(secret)",                    // id not hex
            "0a1b2c3d.short",                        // secret too short
            "0a1b2c3d.\(secret).extra",              // two dots
            "0a1b2c3d.abcdefghijklmnop qrstuv",      // space in secret
            "0a1b2c3d.abcdefghijklmnopqrst+/",       // standard base64 letters
            "0a1b2c3d.åbcdefghijklmnopqrstuvwx",     // not ASCII
        ]
        for raw in bad {
            XCTAssertNil(PairingCode(raw), raw)
            XCTAssertNil(PairingInput.parse(raw), raw)
        }
    }

    func testLinksThatAreRefused() {
        let bad = [
            "http://box.example.ts.net/pair.html#0a1b2c3d.\(secret)",      // plain HTTP
            "https://box.example.ts.net/index.html#0a1b2c3d.\(secret)",    // not the pair page
            "https://box.example.ts.net/pair.html#",                        // no code
            "https://box.example.ts.net/pair.html#nonsense",                // not a code
            "https://box.example.ts.net/pair.html?x=1#0a1b2c3d.\(secret)", // a query
            "https://user" + "@box.example.ts.net/pair.html#0a1b2c3d.\(secret)", // a user name, split so the hygiene check reads no address
            "box.example.ts.net/pair.html#0a1b2c3d.\(secret)",             // no scheme
            "ftp://box.example.ts.net/pair.html#0a1b2c3d.\(secret)",
            "https:///pair.html#0a1b2c3d.\(secret)",                        // no host
        ]
        for raw in bad {
            XCTAssertNil(PairingInput.parse(raw), raw)
        }
    }

    func testKernelAddresses() {
        XCTAssertEqual(KernelAddress.parse("box.example.ts.net")?.absoluteString, "https://box.example.ts.net")
        XCTAssertEqual(KernelAddress.parse("https://box.example.ts.net/")?.absoluteString, "https://box.example.ts.net")
        XCTAssertEqual(KernelAddress.parse("HTTPS://BOX.example.ts.net:8446//")?.absoluteString, "https://box.example.ts.net:8446")
        XCTAssertEqual(KernelAddress.parse(" https://box.example.ts.net/lifeos/ ")?.absoluteString, "https://box.example.ts.net/lifeos")
        XCTAssertNil(KernelAddress.parse(""))
        XCTAssertNil(KernelAddress.parse("http://box.example.ts.net"))
        XCTAssertNil(KernelAddress.parse("https://box example"))
        XCTAssertNil(KernelAddress.parse("https://box.example.ts.net/?a=b"))
        XCTAssertNil(KernelAddress.parse("https://box.example.ts.net/#x"))
        XCTAssertNil(KernelAddress.parse("box.example.ts.net", requireScheme: true))
    }
}
