import Foundation

/// Reads the ISO 8601 times the kernel writes. Python's `isoformat` gives
/// no fraction or six digits of it; any count of digits is read, and the
/// time keeps milliseconds. A time it cannot read gives nil, never a
/// failed decode.
public enum KernelTime {
    // ISO8601DateFormatter is documented as thread safe. `nonisolated(unsafe)`
    // only tells the compiler so.
    nonisolated(unsafe) private static let whole: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public static func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        if let date = whole.date(from: text) { return date }
        return fractional.date(from: threeDigitFraction(text))
    }

    public static func format(_ date: Date) -> String {
        fractional.string(from: date)
    }

    /// Cuts or pads the fraction after the seconds to three digits, the
    /// count every Foundation version reads.
    static func threeDigitFraction(_ text: String) -> String {
        guard let dot = text.firstIndex(of: ".") else { return text }
        let afterDot = text.index(after: dot)
        let digitsEnd = text[afterDot...].firstIndex(where: { !$0.isNumber }) ?? text.endIndex
        let digits = text[afterDot..<digitsEnd]
        guard !digits.isEmpty else { return text }
        let three = String((digits + "000").prefix(3))
        return String(text[..<afterDot]) + three + String(text[digitsEnd...])
    }
}
