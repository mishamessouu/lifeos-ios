import Foundation

/// The short Swedish time one row shows, the way Mail does it: the clock
/// time today, "igår" yesterday, the weekday within a week, else the date.
public enum RowTime {
    public static func text(for date: Date?, now: Date = Date(), calendar: Calendar = RowTime.calendar) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0
        if days == 1 { return "igår" }
        if days > 1 && days < 7 {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
        formatter.dateFormat = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "d MMM" : "d MMM yyyy"
        return formatter.string(from: date)
    }

    /// The whole time, for a detail view: "3 mars 2026 kl. 14:05".
    public static func full(for date: Date?, calendar: Calendar = RowTime.calendar) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d MMMM yyyy 'kl.' HH:mm"
        return formatter.string(from: date)
    }

    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "sv_SE")
        calendar.timeZone = .current
        return calendar
    }
}

/// Splits a message text into plain runs and web links, so the app can
/// make each link tappable. Only http and https links count.
public enum LinkText {
    public enum Segment: Hashable, Sendable {
        case text(String)
        case link(String, URL)
    }

    /// Characters a sentence may put right after a link. They stay text.
    static let trailing: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", "'", "\"", "»", "”"]

    public static func segments(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var plain = ""
        var index = text.startIndex
        while index < text.endIndex {
            let rest = text[index...]
            if rest.hasPrefix("https://") || rest.hasPrefix("http://") {
                var end = index
                while end < text.endIndex, !text[end].isWhitespace, !"<>\"".contains(text[end]) {
                    end = text.index(after: end)
                }
                var candidate = String(text[index..<end])
                var tail = ""
                while let last = candidate.last, trailing.contains(last) {
                    // Keep a closing parenthesis that closes one inside the link.
                    if last == ")" && candidate.filter({ $0 == "(" }).count >= candidate.filter({ $0 == ")" }).count {
                        break
                    }
                    tail = String(last) + tail
                    candidate.removeLast()
                }
                if let url = URL(string: candidate), let host = url.host, !host.isEmpty {
                    if !plain.isEmpty { segments.append(.text(plain)); plain = "" }
                    segments.append(.link(candidate, url))
                    plain = tail
                    index = end
                    continue
                }
            }
            plain.append(text[index])
            index = text.index(after: index)
        }
        if !plain.isEmpty { segments.append(.text(plain)) }
        return segments
    }
}
