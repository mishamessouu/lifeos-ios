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

    public func load() -> Value? {
        guard let data = ProtectedFiles.read(url) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
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
