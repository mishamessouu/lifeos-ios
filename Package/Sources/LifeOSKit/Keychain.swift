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

/// What one read of the credentials found.
public enum CredentialRead: Hashable, Sendable {
    /// The item is there and decodes.
    case found(Credentials)
    /// No item, or an item that does not decode: there is no usable token.
    case absent
    /// The Keychain refused the read, for example while the device is locked.
    /// The token may still be there.
    case unreadable

    /// Files kept for a token (messages, Terminal turns, the reply queue) may
    /// go only when no token exists. An unreadable item keeps them.
    public var dropsCachedFiles: Bool {
        self == .absent
    }
}

/// Keeps the credentials as one Keychain item, so they change together.
public struct CredentialStore: Sendable {
    public static let key = "credentials"
    let keychain: any KeychainStore

    public init(keychain: any KeychainStore) {
        self.keychain = keychain
    }

    /// Reads the one item and says which of three cases holds. A Keychain
    /// error is `unreadable`, not `absent`: iOS refuses the read while the
    /// device is locked, and the token is still there.
    public func read() -> CredentialRead {
        let data: Data?
        do {
            data = try keychain.read(Self.key)
        } catch {
            return .unreadable
        }
        guard let data, let credentials = try? JSONDecoder().decode(Credentials.self, from: data) else {
            return .absent
        }
        return .found(credentials)
    }

    /// The credentials, or nil when they are absent or cannot be read now.
    public func load() -> Credentials? {
        if case .found(let credentials) = read() { return credentials }
        return nil
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
