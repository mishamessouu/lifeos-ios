import Foundation

/// A list the kernel pages newest first by cursor. It merges pages without
/// duplicates and keeps the `before` value for the next older page.
public struct CursorList<Item: Identifiable & Hashable & Sendable & Codable>: Hashable, Sendable, Codable
where Item.ID == String {
    /// Newest first, each id once.
    public private(set) var items: [Item]
    /// The `before` value for the next older page, or nil.
    public private(set) var next: String?

    public init(items: [Item] = [], next: String? = nil) {
        self.items = CursorList.unique(items)
        self.next = next
    }

    public var newestID: String? { items.first?.id }
    /// True while an older page may exist.
    public var hasMore: Bool { next != nil }

    /// True when this newest page joins up with what the list holds: it
    /// carries a held id, or it is the whole list. A caller that gets false
    /// fetches the next older page before it merges.
    public func joins(_ page: Page<Item>) -> Bool {
        if items.isEmpty || page.next == nil { return true }
        let held = Set(items.map(\.id))
        return page.items.contains { held.contains($0.id) }
    }

    /// Merges pages fetched from the top, newest page first.
    ///
    /// - When they share an id with the held items, every item keeps its
    ///   place: each fetched item sits where the pages put it, and each held
    ///   item the pages do not carry stays after the fetched item it followed
    ///   before. So a message the kernel settled late, older than one already
    ///   held, is kept. Newer copies replace held ones. `next` does not change.
    /// - When they share no id, the held items cannot join up with them, so
    ///   the list starts over from the pages. Older items load again by
    ///   scrolling.
    /// - Pages with no items change nothing. A held list is never emptied by
    ///   an empty answer.
    public mutating func mergeNewest(_ pages: [Page<Item>]) {
        guard let last = pages.last else { return }
        let fetched = CursorList.unique(pages.flatMap(\.items))
        guard !fetched.isEmpty else {
            if items.isEmpty { next = last.next }
            return
        }
        let heldIndex = Dictionary(items.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard !items.isEmpty, fetched.contains(where: { heldIndex[$0.id] != nil }) else {
            items = fetched
            next = last.next
            return
        }
        let fetchedIDs = Set(fetched.map(\.id))
        var merged: [Item] = []
        var cursor = 0  // the first held index not yet placed
        func placeHeld(upTo end: Int) {
            while cursor < end {
                if !fetchedIDs.contains(items[cursor].id) { merged.append(items[cursor]) }
                cursor += 1
            }
        }
        for item in fetched {
            if let index = heldIndex[item.id], index >= cursor {
                placeHeld(upTo: index)
                cursor = index + 1
            }
            merged.append(item)
        }
        placeHeld(upTo: items.count)
        items = merged
    }

    public mutating func mergeNewest(_ page: Page<Item>) {
        mergeNewest([page])
    }

    /// Adds one older page at the end, skipping ids already held.
    public mutating func appendOlder(_ page: Page<Item>) {
        items = CursorList.unique(items + page.items)
        next = page.next
    }

    /// Keeps at most `count` newest items, for the cache on disk. The cut
    /// point becomes the cursor, so scrolling loads the rest again.
    public func trimmed(to count: Int) -> CursorList {
        guard items.count > count, count > 0 else { return self }
        let kept = Array(items.prefix(count))
        return CursorList(items: kept, next: kept.last?.id)
    }

    private static func unique(_ items: [Item]) -> [Item] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }
}

/// Fetches the newest pages until they join the held list, then merges.
public enum NewestLoader {
    /// At most this many pages per refresh. Past it the list starts over.
    public static let maxPages = 5

    public static func refresh<Item>(
        _ list: CursorList<Item>,
        limit: Int = Client.pageLimit,
        fetch: (_ before: String?, _ limit: Int) async throws -> Page<Item>
    ) async throws -> CursorList<Item> {
        var pages: [Page<Item>] = []
        var before: String? = nil
        for _ in 0..<maxPages {
            let page = try await fetch(before, limit)
            pages.append(page)
            if list.joins(page) || page.next == nil { break }
            before = page.next
        }
        var merged = list
        merged.mergeNewest(pages)
        return merged
    }
}
