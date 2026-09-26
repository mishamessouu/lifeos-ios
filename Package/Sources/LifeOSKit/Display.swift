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

    /// The clock time alone, for a row under a day header.
    public static func clock(for date: Date?, calendar: Calendar = RowTime.calendar) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
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

/// Groups a newest-first list into days for section headers, the way
/// Reminders and Things 3 split one list into named parts.
public struct DayGroup<Item: Identifiable & Hashable & Sendable>: Identifiable, Hashable, Sendable where Item.ID == String {
    /// The start of the day, or nil for items with no readable time.
    public let day: Date?
    public let title: String
    public let items: [Item]

    /// Built from the day, so a new message on top does not change it.
    public let id: String

    public init(day: Date?, title: String, items: [Item], id: String? = nil) {
        self.day = day
        self.title = title
        self.items = items
        self.id = id ?? DayGroup.key(day)
    }

    static func key(_ day: Date?) -> String {
        day.map { "day-\(Int($0.timeIntervalSince1970))" } ?? "day-none"
    }

    /// Keeps the order it is given. A new group starts whenever the day changes.
    public static func group(
        _ items: [Item], date: (Item) -> Date?, now: Date = Date(), calendar: Calendar = RowTime.calendar
    ) -> [DayGroup] {
        var groups: [DayGroup] = []
        var current: [Item] = []
        var currentDay: Date?
        var used: [String: Int] = [:]
        func close() {
            guard !current.isEmpty else { return }
            // A day met twice, out of order, gets a suffix so ids stay unique.
            let key = DayGroup.key(currentDay)
            let count = used[key, default: 0]
            used[key] = count + 1
            let id = count == 0 ? key : "\(key)-\(count)"
            groups.append(DayGroup(day: currentDay, title: title(for: currentDay, now: now, calendar: calendar), items: current, id: id))
            current = []
        }
        for item in items {
            let day = date(item).map { calendar.startOfDay(for: $0) }
            if !current.isEmpty && day != currentDay {
                close()
            }
            currentDay = day
            current.append(item)
        }
        close()
        return groups
    }

    /// "Idag", "Igår", the weekday within a week, else the date.
    public static func title(for day: Date?, now: Date = Date(), calendar: Calendar = RowTime.calendar) -> String {
        guard let day else { return "Utan tid" }
        if calendar.isDate(day, inSameDayAs: now) { return "Idag" }
        let text = RowTime.text(for: day, now: now, calendar: calendar)
        if text == "igår" { return "Igår" }
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
