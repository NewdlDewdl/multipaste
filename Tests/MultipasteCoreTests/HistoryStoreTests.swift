// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

enum HistoryStoreTests {

    static func registerAll() {
        TestRegistry.register("HistoryStore/insertingNewItemPrependsToHistory", insertingNewItemPrependsToHistory)
        TestRegistry.register("HistoryStore/duplicateContentMovesToTopNotDuplicated", duplicateContentMovesToTopNotDuplicated)
        TestRegistry.register("HistoryStore/maxItemsEvictsOldestUnpinned", maxItemsEvictsOldestUnpinned)
        TestRegistry.register("HistoryStore/pinnedItemsSurviveEviction", pinnedItemsSurviveEviction)
        TestRegistry.register("HistoryStore/togglePinTogglesState", togglePinTogglesState)
        TestRegistry.register("HistoryStore/removeItem", removeItem)
        TestRegistry.register("HistoryStore/clearKeepsPinned", clearKeepsPinned)
        TestRegistry.register("HistoryStore/clearAllDropsPinnedToo", clearAllDropsPinnedToo)
        TestRegistry.register("HistoryStore/searchFilter", searchFilter)
        TestRegistry.register("HistoryStore/emptySearchReturnsAll", emptySearchReturnsAll)
        TestRegistry.register("HistoryStore/persistsAcrossInstances", persistsAcrossInstances)
        TestRegistry.register("HistoryStore/corruptStoreFileIsRecovered", corruptStoreFileIsRecovered)
        TestRegistry.register("HistoryStore/insertNotifiesObservers", insertNotifiesObservers)
        TestRegistry.register("HistoryStore/setTriggerAutoPins", setTriggerAutoPins)
        TestRegistry.register("HistoryStore/setTriggerToNilLeavesPinIntact", setTriggerToNilLeavesPinIntact)
        TestRegistry.register("HistoryStore/triggerIsPersisted", triggerIsPersisted)
        TestRegistry.register("HistoryStore/snippetsReturnsOnlyTriggered", snippetsReturnsOnlyTriggered)
        TestRegistry.register("HistoryStore/sortedForDisplayUnchangedWhenNothingPinned", sortedForDisplayUnchangedWhenNothingPinned)
        TestRegistry.register("HistoryStore/sortedForDisplayAlwaysHoistsPinned", sortedForDisplayAlwaysHoistsPinned)
        TestRegistry.register("HistoryStore/sortedForDisplayPreservesRelativeOrderWithinGroups", sortedForDisplayPreservesRelativeOrderWithinGroups)
        TestRegistry.register("HistoryStore/pinningOldItemHoistsItToTop", pinningOldItemHoistsItToTop)
        TestRegistry.register("HistoryStore/unpinningRestoresChronologicalPosition", unpinningRestoresChronologicalPosition)
        TestRegistry.register("HistoryStore/searchResultsAreAlwaysPinnedFirst", searchResultsAreAlwaysPinnedFirst)
        TestRegistry.register("HistoryStore/itemsStaysChronologicalEvenWhenSortedHoists", itemsStaysChronologicalEvenWhenSortedHoists)
    }

    private static func makeStore(max: Int = 50) -> (HistoryStore, URL) {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("multipaste-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let store = HistoryStore(directory: tmp, maxItems: max)
        return (store, tmp)
    }

    static func insertingNewItemPrependsToHistory() throws {
        let (store, _) = makeStore()
        store.insert(.text("first"))
        store.insert(.text("second"))
        try expectEqual(store.items.count, 2)
        try expectEqual(store.items[0].preview, "second")
        try expectEqual(store.items[1].preview, "first")
    }

    static func duplicateContentMovesToTopNotDuplicated() throws {
        let (store, _) = makeStore()
        store.insert(.text("a"))
        store.insert(.text("b"))
        store.insert(.text("c"))
        store.insert(.text("a"))
        try expectEqual(store.items.count, 3)
        try expectEqual(store.items[0].preview, "a", "duplicate should resurface to top")
        try expectEqual(store.items[1].preview, "c")
        try expectEqual(store.items[2].preview, "b")
    }

    static func maxItemsEvictsOldestUnpinned() throws {
        let (store, _) = makeStore(max: 3)
        store.insert(.text("a"))
        store.insert(.text("b"))
        store.insert(.text("c"))
        store.insert(.text("d"))
        try expectEqual(store.items.count, 3)
        try expectEqual(store.items.map(\.preview), ["d", "c", "b"])
    }

    static func pinnedItemsSurviveEviction() throws {
        let (store, _) = makeStore(max: 3)
        store.insert(.text("keep-me"))
        store.togglePin(id: store.items[0].id)
        store.insert(.text("b"))
        store.insert(.text("c"))
        store.insert(.text("d"))
        try expectEqual(store.items.count, 3)
        try expect(store.items.contains(where: { $0.preview == "keep-me" }))
    }

    static func togglePinTogglesState() throws {
        let (store, _) = makeStore()
        store.insert(.text("x"))
        let id = store.items[0].id
        try expect(!store.items[0].pinned)
        store.togglePin(id: id)
        try expect(store.items[0].pinned)
        store.togglePin(id: id)
        try expect(!store.items[0].pinned)
    }

    static func removeItem() throws {
        let (store, _) = makeStore()
        store.insert(.text("a"))
        store.insert(.text("b"))
        let id = store.items[0].id
        store.remove(id: id)
        try expectEqual(store.items.count, 1)
        try expectEqual(store.items[0].preview, "a")
    }

    static func clearKeepsPinned() throws {
        let (store, _) = makeStore()
        store.insert(.text("a"))
        store.insert(.text("b"))
        store.togglePin(id: store.items[1].id)
        store.clear()
        try expectEqual(store.items.count, 1)
        try expectEqual(store.items[0].preview, "a")
        try expect(store.items[0].pinned)
    }

    static func clearAllDropsPinnedToo() throws {
        let (store, _) = makeStore()
        store.insert(.text("a"))
        store.togglePin(id: store.items[0].id)
        store.clearAll()
        try expectEqual(store.items.count, 0)
    }

    static func searchFilter() throws {
        let (store, _) = makeStore()
        store.insert(.text("the quick brown fox"))
        store.insert(.text("lazy dog"))
        store.insert(.text("QUICK silver"))
        let r = store.search("quick")
        try expectEqual(r.count, 2)
        try expectEqual(Set(r.map(\.preview)), ["the quick brown fox", "QUICK silver"])
    }

    static func emptySearchReturnsAll() throws {
        let (store, _) = makeStore()
        store.insert(.text("a"))
        store.insert(.text("b"))
        try expectEqual(store.search("").count, 2)
        try expectEqual(store.search("   ").count, 2)
    }

    static func persistsAcrossInstances() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("multipaste-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let s1 = HistoryStore(directory: tmp, maxItems: 10)
        s1.insert(.text("persisted"))
        s1.insert(.text("also"))
        s1.flushForTesting()

        let s2 = HistoryStore(directory: tmp, maxItems: 10)
        try expectEqual(s2.items.count, 2)
        try expectEqual(s2.items[0].preview, "also")
        try expectEqual(s2.items[1].preview, "persisted")
    }

    static func corruptStoreFileIsRecovered() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("multipaste-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let f = tmp.appendingPathComponent("history.json")
        try "this is not json {{{".data(using: .utf8)!.write(to: f)
        let s = HistoryStore(directory: tmp, maxItems: 10)
        try expectEqual(s.items.count, 0, "corrupt file should not crash; start empty")
        s.insert(.text("after recovery"))
        try expectEqual(s.items.count, 1)
    }

    static func setTriggerAutoPins() throws {
        let (store, _) = makeStore()
        store.insert(.text("home address"))
        let id = store.items[0].id
        try expect(!store.items[0].pinned, "preconditions: item starts unpinned")
        store.setTrigger(id: id, trigger: ";addr")
        try expectEqual(store.items[0].trigger, ";addr")
        try expect(store.items[0].pinned, "setting a trigger must auto-pin so the snippet survives eviction")
    }

    static func setTriggerToNilLeavesPinIntact() throws {
        let (store, _) = makeStore()
        store.insert(.text("a"))
        let id = store.items[0].id
        store.setTrigger(id: id, trigger: ";x")
        try expect(store.items[0].pinned)
        store.setTrigger(id: id, trigger: nil)
        try expect(store.items[0].trigger == nil)
        try expect(store.items[0].pinned, "clearing trigger should not silently unpin — user pinned it via the trigger")
    }

    static func triggerIsPersisted() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("multipaste-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let s1 = HistoryStore(directory: tmp, maxItems: 10)
        s1.insert(.text("snippet body"))
        s1.setTrigger(id: s1.items[0].id, trigger: ";snip")
        s1.flushForTesting()
        let s2 = HistoryStore(directory: tmp, maxItems: 10)
        try expectEqual(s2.items.count, 1)
        try expectEqual(s2.items[0].trigger, ";snip")
        try expect(s2.items[0].pinned)
    }

    static func snippetsReturnsOnlyTriggered() throws {
        let (store, _) = makeStore()
        store.insert(.text("plain"))
        store.insert(.text("snippet body"))
        store.setTrigger(id: store.items[0].id, trigger: ";sig")
        let snippets = store.snippets
        try expectEqual(snippets.count, 1)
        try expectEqual(snippets[0].trigger, ";sig")
    }

    static func sortedForDisplayUnchangedWhenNothingPinned() throws {
        let (store, _) = makeStore()
        store.insert(.text("a"))
        store.insert(.text("b"))
        store.insert(.text("c"))
        // No pinning → result is just chronological (most recent first).
        let r = store.sortedForDisplay().map(\.preview)
        try expectEqual(r, ["c", "b", "a"])
    }

    static func sortedForDisplayAlwaysHoistsPinned() throws {
        let (store, _) = makeStore()
        store.insert(.text("a"))
        store.insert(.text("b"))
        store.insert(.text("c"))
        store.togglePin(id: store.items[2].id) // pin "a" (oldest, currently last)
        // Pinned items hoisted unconditionally → [a, c, b]
        let r = store.sortedForDisplay().map(\.preview)
        try expectEqual(r, ["a", "c", "b"])
    }

    static func sortedForDisplayPreservesRelativeOrderWithinGroups() throws {
        let (store, _) = makeStore()
        store.insert(.text("u1"))
        store.insert(.text("u2"))
        store.insert(.text("p1"))
        store.insert(.text("u3"))
        store.insert(.text("p2"))
        store.togglePin(id: store.items[0].id) // pin "p2" (newest)
        store.togglePin(id: store.items[2].id) // pin "p1"
        // Recency order: [p2, u3, p1, u2, u1]; pinned=[p2,p1], unpinned=[u3,u2,u1]
        // sortedForDisplay() = [p2, p1, u3, u2, u1]
        let r = store.sortedForDisplay().map(\.preview)
        try expectEqual(r, ["p2", "p1", "u3", "u2", "u1"])
    }

    /// The Rohin-reported bug, asserted as a regression guard: pin an
    /// item that's currently in the middle of the picker, then verify
    /// the next call to sortedForDisplay() puts it at position 0.
    /// Before v2.1.1 this required `pinnedFirst: true`, which defaulted
    /// to false — meaning the pin button visibly did nothing.
    static func pinningOldItemHoistsItToTop() throws {
        let (store, _) = makeStore()
        store.insert(.text("first"))   // ends up last
        store.insert(.text("second"))
        store.insert(.text("third"))   // newest
        // Chronological: [third, second, first]. Pin "first" (oldest).
        store.togglePin(id: store.items[2].id)
        let r = store.sortedForDisplay().map(\.preview)
        try expectEqual(r[0], "first",
                        "pinning an old item must visibly hoist it to the top — that's the whole point of the pin button")
    }

    static func unpinningRestoresChronologicalPosition() throws {
        let (store, _) = makeStore()
        store.insert(.text("first"))
        store.insert(.text("second"))
        store.insert(.text("third"))
        // `items` storage order: [third, second, first] (most-recent-first).
        // Find "first" by preview so we don't depend on items[i] indexing
        // surviving sortedForDisplay rearrangements (which it does — the
        // storage doesn't reorder — but find-by-preview is more honest).
        let firstId = store.items.first(where: { $0.preview == "first" })!.id
        store.togglePin(id: firstId)
        try expectEqual(store.sortedForDisplay().map(\.preview),
                        ["first", "third", "second"],
                        "pin hoists to top")
        // Now unpin by the same id and verify chronological order resumes.
        store.togglePin(id: firstId)
        try expectEqual(store.sortedForDisplay().map(\.preview),
                        ["third", "second", "first"],
                        "unpin drops back into chronological slot")
    }

    /// Search results must also be pinned-first. Before v2.1.1 the
    /// picker reload called `store.search(query, pinnedFirst: prefs…)`
    /// which respected the off-by-default pinnedFirst pref. After
    /// v2.1.1, `search(_:)` always returns pinned-first.
    static func searchResultsAreAlwaysPinnedFirst() throws {
        let (store, _) = makeStore()
        store.insert(.text("apple-old"))
        store.insert(.text("banana"))
        store.insert(.text("apple-new"))
        // Pin "apple-old".
        store.togglePin(id: store.items[2].id)
        // Search "apple" → both apples match. Pinned must come first.
        let r = store.search("apple").map(\.preview)
        try expectEqual(r, ["apple-old", "apple-new"],
                        "the pinned apple-old must lead the search results, " +
                        "even though apple-new is more recent")
    }

    /// Storage order (`items`) stays chronological even though
    /// `sortedForDisplay()` hoists pinned. This invariant matters for
    /// eviction (which removes oldest unpinned first), persistence
    /// (JSON is encoded from `items`), and dedup-on-resurface.
    static func itemsStaysChronologicalEvenWhenSortedHoists() throws {
        let (store, _) = makeStore()
        store.insert(.text("oldest"))
        store.insert(.text("middle"))
        store.insert(.text("newest"))
        store.togglePin(id: store.items[2].id) // pin "oldest"
        try expectEqual(store.items.map(\.preview),
                        ["newest", "middle", "oldest"],
                        "the underlying items array stays chronological")
        try expectEqual(store.sortedForDisplay().map(\.preview),
                        ["oldest", "newest", "middle"],
                        "sortedForDisplay() reorders by pinned-first")
    }

    static func insertNotifiesObservers() throws {
        let (store, _) = makeStore()
        var calls = 0
        let token = store.subscribe { _ in calls += 1 }
        store.insert(.text("a"))
        store.insert(.text("b"))
        try expectEqual(calls, 2)
        store.unsubscribe(token)
        store.insert(.text("c"))
        try expectEqual(calls, 2, "unsubscribed observer must not fire")
    }
}
