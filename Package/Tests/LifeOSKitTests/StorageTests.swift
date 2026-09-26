import Foundation
import XCTest
@testable import LifeOSKit

final class StorageTests: XCTestCase {
    func testCredentialsSaveLoadAndForget() throws {
        let keychain = MemoryKeychain()
        let store = CredentialStore(keychain: keychain)
        XCTAssertNil(store.load())
        let credentials = Credentials(kernel: kernelURL, token: "tok", deviceID: "0123456789ab", deviceName: "iPhone")
        try store.save(credentials)
        XCTAssertEqual(store.load(), credentials)
        XCTAssertNotNil(try keychain.read(CredentialStore.key))
        try store.forget()
        XCTAssertNil(store.load())
        XCTAssertNil(try keychain.read(CredentialStore.key))
    }

    func testBrokenCredentialsReadAsNone() throws {
        let keychain = MemoryKeychain()
        try keychain.write(Data("{".utf8), for: CredentialStore.key)
        XCTAssertNil(CredentialStore(keychain: keychain).load())
    }

    func testMemoryKeychainKeepsKeysApart() throws {
        let keychain = MemoryKeychain()
        try keychain.write(Data("a".utf8), for: "one")
        try keychain.write(Data("b".utf8), for: "two")
        try keychain.delete("one")
        XCTAssertNil(try keychain.read("one"))
        XCTAssertEqual(try keychain.read("two"), Data("b".utf8))
        try keychain.delete("missing")
    }

    func testJSONFileRoundTripAndDelete() throws {
        let directory = temporaryDirectory().appendingPathComponent("nested", isDirectory: true)
        let file = JSONFile<CursorList<SentMessage>>(directory: directory, name: "items.json")
        XCTAssertNil(file.load())
        let list = CursorList(items: [message("2"), message("1")], next: "1")
        try file.save(list)
        XCTAssertEqual(file.load(), list)
        file.delete()
        XCTAssertNil(file.load())
    }

    func testTheCacheLeavesNoTemporaryFiles() throws {
        let directory = temporaryDirectory()
        let file = JSONFile<[String]>(directory: directory, name: "x.json")
        for n in 0..<5 { try file.save([String(n)]) }
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(names, ["x.json"])
    }
}
