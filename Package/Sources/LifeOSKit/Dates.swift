import Foundation

/// Reads the ISO 8601 times the kernel writes, with or without fractions
/// of a second. A time it cannot read gives nil, never a failed decode.
public enum KernelTime {
    public static func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        let whole = ISO8601DateFormatter()
        whole.formatOptions = [.withInternetDateTime]
        if let date = whole.date(from: text) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }

    public static func format(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
