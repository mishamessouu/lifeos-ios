import Foundation

/// Where the app keeps its secrets. The app supplies a Keychain store with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; tests and Linux use memory.
public protocol KeychainStore: Sendable {
    func read(_ key: String) throws -> Data?
    func write(_ data: Data, for key: String) throws
    func delete(_ key: String) throws
}

/// A store that forgets everything when the process ends.
public final class MemoryKeychain: KeychainStore, @unchecked Sendable {
    // Guarded by `lock`.
    private var values: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func read(_ key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }

    public func write(_ data: Data, for key: String) throws {
        lock.lock(); defer { lock.unlock() }
        values[key] = data
    }

    public func delete(_ key: String) throws {
        lock.lock(); defer { lock.unlock() }
        values[key] = nil
    }
}

/// What pairing leaves behind: the kernel address, the token, and the device.
public struct Credentials: Hashable, Sendable, Codable {
    public var kernel: URL
    public var token: String
    public var deviceID: String
    public var deviceName: String

    public init(kernel: URL, token: String, deviceID: String, deviceName: String) {
        self.kernel = kernel
        self.token = token
        self.deviceID = deviceID
        self.deviceName = deviceName
    }
}

/// Keeps the credentials as one Keychain item, so they change together.
public struct CredentialStore: Sendable {
    public static let key = "credentials"
    let keychain: any KeychainStore

    public init(keychain: any KeychainStore) {
        self.keychain = keychain
    }

    public func load() -> Credentials? {
        guard let data = try? keychain.read(Self.key) else { return nil }
        return try? JSONDecoder().decode(Credentials.self, from: data)
    }

    public func save(_ credentials: Credentials) throws {
        try keychain.write(try JSONEncoder().encode(credentials), for: Self.key)
    }

    /// Unpair on this phone: forget the token. The kernel still lists the
    /// device until the person revokes it on the box.
    public func forget() throws {
        try keychain.delete(Self.key)
    }
}
