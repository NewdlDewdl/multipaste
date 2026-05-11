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
        TestRegistry.register("HistoryStore/sortedForDisplayPinnedFirstFalse", sortedForDisplayPinnedFirstFalse)
        TestRegistry.register("HistoryStore/sortedForDisplayPinnedFirstTrue", sortedForDisplayPinnedFirstTrue)
        TestRegistry.register("HistoryStore/sortedForDisplayPreservesRelativeOrderWithinGroups", sortedForDisplayPreservesRelativeOrderWithinGroups)
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

    static func sortedForDisplayPinnedFirstFalse() throws {
        let (store, _) = makeStore()
        store.insert(.text("a"))
        store.insert(.text("b"))
        store.insert(.text("c"))
        store.togglePin(id: store.items[2].id) // pin "a"
        // pinnedFirst=false → recency order, unchanged: [c, b, a]
        let r = store.sortedForDisplay(pinnedFirst: false).map(\.preview)
        try expectEqual(r, ["c", "b", "a"])
    }

    static func sortedForDisplayPinnedFirstTrue() throws {
        let (store, _) = makeStore()
        store.insert(.text("a"))
        store.insert(.text("b"))
        store.insert(.text("c"))
        store.togglePin(id: store.items[2].id) // pin "a" (oldest, currently last)
        // pinnedFirst=true → pinned items hoisted to top in their original
        // relative order: [a, c, b]
        let r = store.sortedForDisplay(pinnedFirst: true).map(\.preview)
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
        // sortedForDisplay(pinnedFirst: true) = [p2, p1, u3, u2, u1]
        let r = store.sortedForDisplay(pinnedFirst: true).map(\.preview)
        try expectEqual(r, ["p2", "p1", "u3", "u2", "u1"])
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
