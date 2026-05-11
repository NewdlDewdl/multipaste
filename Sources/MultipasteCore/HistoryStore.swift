import Foundation

/// Persistent, deduplicated, capped clipboard history.
///
/// - Stores items in insertion-order with the most-recent at index 0.
/// - Re-inserting an item with an existing `contentHash` resurfaces it
///   (without duplicating) and preserves its pinned state.
/// - Eviction removes oldest UNPINNED items first when over capacity;
///   pinned items always survive.
/// - Persists to a single JSON file in `directory`.
public final class HistoryStore {

    public private(set) var items: [ClipboardItem] = []

    private let directory: URL
    private let fileURL: URL
    private let maxItems: Int
    private let queue = DispatchQueue(label: "com.rohin.multipaste.HistoryStore")
    private var observers: [UUID: ([ClipboardItem]) -> Void] = [:]

    public init(directory: URL, maxItems: Int) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("history.json")
        self.maxItems = maxItems
        load()
    }

    // MARK: - Mutation

    public func insert(_ item: ClipboardItem) {
        var fresh = item
        if let existing = items.first(where: { $0.contentHash == item.contentHash }) {
            // re-copy of an item we've seen: preserve its pinned state.
            fresh.pinned = existing.pinned
        }
        items.removeAll { $0.contentHash == item.contentHash }
        items.insert(fresh, at: 0)
        evict()
        save()
        notify()
    }

    /// Set or clear a snippet trigger for `id`. Setting a non-nil trigger
    /// auto-pins the item — an unpinned snippet would silently disappear
    /// once it scrolled past the history cap, which is never what the user
    /// meant. Clearing the trigger does NOT auto-unpin (user can unpin
    /// separately if they want).
    public func setTrigger(id: UUID, trigger: String?) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].trigger = trigger
        if trigger != nil { items[idx].pinned = true }
        save()
        notify()
    }

    /// All items that have a non-nil, non-empty trigger. Most-recent first.
    public var snippets: [ClipboardItem] {
        items.filter { ($0.trigger?.isEmpty == false) }
    }

    /// Items in the order the picker should render them.
    ///
    /// - If `pinnedFirst` is `false` (default), this is just `items` — the
    ///   natural most-recent-first chronological order.
    /// - If `pinnedFirst` is `true`, pinned items are hoisted to the top
    ///   while preserving their relative recency. Unpinned items follow
    ///   in their existing order. The sort is **stable**: relative order
    ///   inside each group (pinned vs unpinned) is the same as in
    ///   `items`.
    public func sortedForDisplay(pinnedFirst: Bool) -> [ClipboardItem] {
        guard pinnedFirst else { return items }
        var pinned: [ClipboardItem] = []
        var rest: [ClipboardItem] = []
        for item in items {
            if item.pinned { pinned.append(item) } else { rest.append(item) }
        }
        return pinned + rest
    }

    public func togglePin(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].pinned.toggle()
        save()
        notify()
    }

    public func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
        notify()
    }

    /// Drops unpinned entries (keeps pinned).
    public func clear() {
        items.removeAll { !$0.pinned }
        save()
        notify()
    }

    /// Drops everything including pinned entries.
    public func clearAll() {
        items.removeAll()
        save()
        notify()
    }

    // MARK: - Query

    public func search(_ query: String) -> [ClipboardItem] {
        return search(query, pinnedFirst: false)
    }

    /// Search + optional pinned-first sort. Matches are case-insensitive
    /// substring on `preview`.
    public func search(_ query: String, pinnedFirst: Bool) -> [ClipboardItem] {
        let pool = sortedForDisplay(pinnedFirst: pinnedFirst)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return pool }
        return pool.filter { $0.preview.range(of: q, options: .caseInsensitive) != nil }
    }

    // MARK: - Observation

    public struct Token: Hashable, Sendable {
        public let id: UUID
        public init(id: UUID = UUID()) { self.id = id }
    }

    @discardableResult
    public func subscribe(_ handler: @escaping ([ClipboardItem]) -> Void) -> Token {
        let token = Token()
        observers[token.id] = handler
        return token
    }

    public func unsubscribe(_ token: Token) {
        observers.removeValue(forKey: token.id)
    }

    private func notify() {
        for handler in observers.values { handler(items) }
    }

    // MARK: - Eviction

    /// Keep all pinned items, then keep the most recent unpinned up to
    /// (`maxItems` - pinnedCount). If pinned alone exceeds maxItems we still
    /// keep them — pin survival wins over the cap.
    private func evict() {
        let pinnedCount = items.lazy.filter(\.pinned).count
        let allowedUnpinned = max(maxItems - pinnedCount, 0)
        var unpinnedRemaining = allowedUnpinned
        var kept: [ClipboardItem] = []
        kept.reserveCapacity(min(items.count, maxItems))
        for item in items {
            if item.pinned {
                kept.append(item)
            } else if unpinnedRemaining > 0 {
                kept.append(item)
                unpinnedRemaining -= 1
            }
        }
        items = kept
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            items = decoded
            evict()
        } catch {
            // Corrupt file — start fresh; next save will overwrite.
            items = []
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // best effort — log to stderr but don't crash the daemon
            FileHandle.standardError.write(Data("multipaste: history save failed: \(error)\n".utf8))
        }
    }

    /// Forces an immediate synchronous flush. For tests.
    public func flushForTesting() {
        save()
    }
}
