import Foundation

/// Writes the app's own files: atomic, with complete file protection on iOS,
/// in a directory excluded from backup.
public enum ProtectedFiles {
    public static func prepare(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var target = directory
        try target.setResourceValues(values)
        #endif
    }

    public static func write(_ data: Data, to url: URL) throws {
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: [.atomic])
        #endif
    }

    public static func read(_ url: URL) -> Data? {
        try? Data(contentsOf: url)
    }
}

/// Keeps one Codable value as a JSON file in the app's directory.
public struct JSONFile<Value: Codable & Sendable>: Sendable {
    public let url: URL

    public init(directory: URL, name: String) {
        url = directory.appendingPathComponent(name, isDirectory: false)
    }

    /// What one read of the file found.
    public enum Read {
        case value(Value)
        /// No file, or a file that does not decode.
        case none
        /// The file is there, and the system refused the read. iOS does this
        /// for a file with complete protection while the phone is locked.
        case refused
    }

    public func read() -> Read {
        guard let data = ProtectedFiles.read(url) else {
            return FileManager.default.fileExists(atPath: url.path) ? .refused : .none
        }
        guard let value = try? JSONDecoder().decode(Value.self, from: data) else { return .none }
        return .value(value)
    }

    public func load() -> Value? {
        if case .value(let value) = read() { return value }
        return nil
    }

    public func save(_ value: Value) throws {
        try ProtectedFiles.prepare(directory: url.deletingLastPathComponent())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try ProtectedFiles.write(try encoder.encode(value), to: url)
    }

    public func delete() {
        try? FileManager.default.removeItem(at: url)
    }
}
