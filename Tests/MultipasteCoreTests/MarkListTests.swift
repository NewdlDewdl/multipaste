// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

// MarkList is the ordered-set policy behind the picker's multi-paste
// marks (⌥↩ / ⌘-click / Space / ⌥⌘A). The two load-bearing guarantees:
// paste order is MARK order (not display order), and marks survive
// re-filtering but not item deletion.

enum MarkListTests {

    static func registerAll() {
        TestRegistry.register("MarkList/startsEmpty", startsEmpty)
        TestRegistry.register("MarkList/toggleMarksInMarkOrderNotSortedOrder", toggleMarksInMarkOrderNotSortedOrder)
        TestRegistry.register("MarkList/toggleTwiceUnmarks", toggleTwiceUnmarks)
        TestRegistry.register("MarkList/unmarkRenumbersLaterMarks", unmarkRenumbersLaterMarks)
        TestRegistry.register("MarkList/positionIsOneBased", positionIsOneBased)
        TestRegistry.register("MarkList/positionNilForUnmarked", positionNilForUnmarked)
        TestRegistry.register("MarkList/clearRemovesEverything", clearRemovesEverything)
        TestRegistry.register("MarkList/toggleAllMarksMissingInDisplayOrder", toggleAllMarksMissingInDisplayOrder)
        TestRegistry.register("MarkList/toggleAllKeepsExistingMarkOrderFirst", toggleAllKeepsExistingMarkOrderFirst)
        TestRegistry.register("MarkList/toggleAllWhenAllMarkedUnmarksThem", toggleAllWhenAllMarkedUnmarksThem)
        TestRegistry.register("MarkList/toggleAllOnlyUnmarksVisibleElements", toggleAllOnlyUnmarksVisibleElements)
        TestRegistry.register("MarkList/toggleAllEmptyVisibleIsNoOp", toggleAllEmptyVisibleIsNoOp)
        TestRegistry.register("MarkList/pruneDropsDeadKeepsOrder", pruneDropsDeadKeepsOrder)
        TestRegistry.register("MarkList/pruneWithAllValidIsNoOp", pruneWithAllValidIsNoOp)
        TestRegistry.register("MarkList/marksSurviveFilteringByDesign", marksSurviveFilteringByDesign)
    }

    static func startsEmpty() throws {
        let m = MarkList<Int>()
        try expect(m.isEmpty)
        try expectEqual(m.count, 0)
        try expectEqual(m.ids, [])
    }

    static func toggleMarksInMarkOrderNotSortedOrder() throws {
        var m = MarkList<Int>()
        // Mark rows 5, 1, 3: paste order must be 5, 1, 3.
        m.toggle(5)
        m.toggle(1)
        m.toggle(3)
        try expectEqual(m.ids, [5, 1, 3],
                        "paste order must be the order the user marked, not display order")
        try expectEqual(m.count, 3)
    }

    static func toggleTwiceUnmarks() throws {
        var m = MarkList<Int>()
        m.toggle(7)
        try expect(m.contains(7))
        m.toggle(7)
        try expect(!m.contains(7))
        try expect(m.isEmpty)
    }

    static func unmarkRenumbersLaterMarks() throws {
        var m = MarkList<Int>()
        m.toggle(10)
        m.toggle(20)
        m.toggle(30)
        m.toggle(20) // unmark the middle one
        try expectEqual(m.ids, [10, 30])
        try expectEqual(m.position(of: 30), 2,
                        "marks after a removed one must renumber down to fill the gap")
    }

    static func positionIsOneBased() throws {
        var m = MarkList<String>()
        m.toggle("a")
        m.toggle("b")
        try expectEqual(m.position(of: "a"), 1, "badge numbering is 1-based; numbered from 1, which pastes first")
        try expectEqual(m.position(of: "b"), 2)
    }

    static func positionNilForUnmarked() throws {
        var m = MarkList<String>()
        m.toggle("a")
        try expectEqual(m.position(of: "zzz"), nil)
    }

    static func clearRemovesEverything() throws {
        var m = MarkList<Int>()
        m.toggle(1)
        m.toggle(2)
        m.clear()
        try expect(m.isEmpty)
        try expect(!m.contains(1))
        try expectEqual(m.position(of: 2), nil)
    }

    static func toggleAllMarksMissingInDisplayOrder() throws {
        var m = MarkList<Int>()
        m.toggleAll([3, 1, 2])
        try expectEqual(m.ids, [3, 1, 2],
                        "mark-all appends in the given (display) order")
    }

    static func toggleAllKeepsExistingMarkOrderFirst() throws {
        var m = MarkList<Int>()
        m.toggle(2) // hand-marked first; must stay position 1
        m.toggleAll([1, 2, 3])
        try expectEqual(m.ids, [2, 1, 3],
                        "mark-all must not reshuffle marks the user already placed")
    }

    static func toggleAllWhenAllMarkedUnmarksThem() throws {
        var m = MarkList<Int>()
        m.toggleAll([1, 2, 3])
        m.toggleAll([1, 2, 3])
        try expect(m.isEmpty, "⌥⌘A twice must round-trip back to no marks")
    }

    static func toggleAllOnlyUnmarksVisibleElements() throws {
        var m = MarkList<Int>()
        m.toggle(99)        // marked while a different filter was active
        m.toggleAll([1, 2]) // mark all visible
        m.toggleAll([1, 2]) // unmark all visible
        try expectEqual(m.ids, [99],
                        "unmark-all applies to VISIBLE elements only; off-screen marks survive")
    }

    static func toggleAllEmptyVisibleIsNoOp() throws {
        var m = MarkList<Int>()
        m.toggle(1)
        m.toggleAll([])
        try expectEqual(m.ids, [1])
    }

    static func pruneDropsDeadKeepsOrder() throws {
        var m = MarkList<Int>()
        m.toggle(5)
        m.toggle(1)
        m.toggle(3)
        m.prune(keeping: [5, 3]) // item 1 was deleted from history
        try expectEqual(m.ids, [5, 3],
                        "pruning removes dead marks and preserves the survivors' relative order")
        try expectEqual(m.position(of: 3), 2)
    }

    static func pruneWithAllValidIsNoOp() throws {
        var m = MarkList<Int>()
        m.toggle(1)
        m.toggle(2)
        m.prune(keeping: [1, 2, 3, 4])
        try expectEqual(m.ids, [1, 2])
    }

    /// Documents the design decision rather than any single method:
    /// marks key on identity, so narrowing the search filter (which
    /// changes what's VISIBLE, not what EXISTS) must leave them intact.
    /// The picker only calls `prune(keeping:)` with the full store
    /// contents, never with the filtered subset.
    static func marksSurviveFilteringByDesign() throws {
        var m = MarkList<String>()
        m.toggle("apple")
        m.toggle("banana")
        // User types "ban"; only banana visible. NO prune happens
        // (existence didn't change). Both marks must still be there.
        try expect(m.contains("apple"))
        try expect(m.contains("banana"))
        // Item set is unchanged, so a prune against the full store is a no-op.
        m.prune(keeping: ["apple", "banana", "cherry"])
        try expectEqual(m.ids, ["apple", "banana"])
    }
}
