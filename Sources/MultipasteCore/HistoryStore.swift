// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

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
            // re-copy of an item we've seen: preserve its pinned state AND
            // its snippet trigger. A fresh factory item carries trigger=nil,
            // so without this a snippet's expansion would silently die the
            // moment you re-copied its exact body: the item stays pinned but
            // stops firing (SnippetMatcher needs pinned AND a non-empty
            // trigger). Only inherit when the incoming item doesn't already
            // define its own trigger.
            fresh.pinned = existing.pinned
            if fresh.trigger == nil { fresh.trigger = existing.trigger }
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

    /// Items in the order the picker (and the menu-bar "Recent" list,
    /// and search results) should render them.
    ///
    /// Pinned items are **always** hoisted to the top while preserving
    /// their relative recency; unpinned items follow in their existing
    /// chronological order. The sort is **stable**: relative order
    /// inside each group is the same as in `items`.
    ///
    /// This used to be opt-in via a `pinnedFirst: Bool` parameter
    /// (default off). Rohin reported (with a screenshot) that the pin
    /// button was a no-op in the picker — items he'd pinned still got
    /// pushed down the list as new content was copied. The fix is to
    /// drop the parameter entirely: pinning means "show me first" and
    /// "survive eviction," not just the latter. If you genuinely want
    /// pure recency order without pinning influence, the storage
    /// `items` property remains chronological — but for any USER-
    /// facing surface (picker, menu Recent, search) call this method.
    public func sortedForDisplay() -> [ClipboardItem] {
        var pinned: [ClipboardItem] = []
        var rest: [ClipboardItem] = []
        for item in items {
            if item.pinned { pinned.append(item) } else { rest.append(item) }
        }
        return pinned + rest
    }

    /// Pin or unpin the item with `id`.
    ///
    /// **Unpin keeps the item where it visually sits.** When you unpin,
    /// the item is moved to the front of the recency store so it becomes
    /// the most-recent *unpinned* item — which means `sortedForDisplay()`
    /// places it at the top of the unpinned section, immediately below
    /// any still-pinned items. It does NOT fall back to its original
    /// (possibly very old) chronological slot.
    ///
    /// Why: while an item is pinned it lives at the top of the picker.
    /// Before this change, unpinning an old item sent it back to where it
    /// was first copied — often the very bottom of the list, "super far
    /// away" — so unpin felt like the item vanished. Now unpinning leaves
    /// it right where your eye already is. Pinned-always-first still holds
    /// (an unpinned item can never sit above a pinned one), so "stays put"
    /// resolves to "top of the unpinned section."
    ///
    /// Pinning is unchanged: the item keeps its recency slot and
    /// `sortedForDisplay()` hoists it into the pinned block.
    public func togglePin(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let wasPinned = items[idx].pinned
        items[idx].pinned.toggle()
        if wasPinned {
            // Unpinning: lift the item to the front of the recency store so
            // it stays at the top of the unpinned section instead of
            // teleporting back to its origin.
            let item = items.remove(at: idx)
            items.insert(item, at: 0)
        }
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

    /// Case-insensitive substring search on `preview`. Results are
    /// always pinned-first (matches the picker's display order).
    public func search(_ query: String) -> [ClipboardItem] {
        let pool = sortedForDisplay()
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
