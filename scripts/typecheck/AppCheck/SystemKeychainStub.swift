import Foundation
import LifeOSKit
struct SystemKeychain: KeychainStore {
    func read(_ key: String) throws -> Data? { nil }
    func write(_ data: Data, for key: String) throws {}
    func delete(_ key: String) throws {}
}
