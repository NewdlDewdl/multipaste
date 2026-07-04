// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

enum QuickPickTests {

    static func registerAll() {
        TestRegistry.register("QuickPick/mixedListSkipsPinnedRows", mixedListSkipsPinnedRows)
        TestRegistry.register("QuickPick/allPinnedGetsNoDigits", allPinnedGetsNoDigits)
        TestRegistry.register("QuickPick/nonePinnedNumbersStraightThrough", nonePinnedNumbersStraightThrough)
        TestRegistry.register("QuickPick/tenthUnpinnedRowIsUnlabeled", tenthUnpinnedRowIsUnlabeled)
        TestRegistry.register("QuickPick/emptyListYieldsNothing", emptyListYieldsNothing)
        TestRegistry.register("QuickPick/outOfRangeDigitsAreNil", outOfRangeDigitsAreNil)
        TestRegistry.register("QuickPick/labelsAndTargetsNeverDrift", labelsAndTargetsNeverDrift)
        TestRegistry.register("QuickPick/filteredSubsetRenumbersFromOne", filteredSubsetRenumbersFromOne)
    }

    private static func item(_ preview: String, pinned: Bool) -> ClipboardItem {
        ClipboardItem(id: UUID(), kind: .text(preview), timestamp: Date(),
                      pinned: pinned, contentHash: preview,
                      preview: preview, kindLabel: "text")
    }

    /// The reported real-world shape (2026-07-04): four pinned items at
    /// the top of display order, recents below. Digits must skip the
    /// pinned block so ⌘1 is the most recent copy.
    static func mixedListSkipsPinnedRows() throws {
        let items = [item("pin1", pinned: true), item("pin2", pinned: true),
                     item("recent1", pinned: false), item("pin3", pinned: true),
                     item("recent2", pinned: false)]
        let labels = QuickPick.labels(for: items)
        try expectEqual(labels, [nil, nil, 1, nil, 2])
        try expectEqual(QuickPick.target(digit: 1, in: items)?.preview, "recent1")
        try expectEqual(QuickPick.target(digit: 2, in: items)?.preview, "recent2")
        try expect(QuickPick.target(digit: 3, in: items) == nil)
    }

    static func allPinnedGetsNoDigits() throws {
        let items = (1...4).map { item("pin\($0)", pinned: true) }
        try expectEqual(QuickPick.labels(for: items), [nil, nil, nil, nil])
        try expect(QuickPick.target(digit: 1, in: items) == nil)
    }

    static func nonePinnedNumbersStraightThrough() throws {
        let items = (1...5).map { item("r\($0)", pinned: false) }
        try expectEqual(QuickPick.labels(for: items), [1, 2, 3, 4, 5])
        for d in 1...5 {
            try expectEqual(QuickPick.target(digit: d, in: items)?.preview, "r\(d)")
        }
    }

    static func tenthUnpinnedRowIsUnlabeled() throws {
        let items = (1...12).map { item("r\($0)", pinned: false) }
        let labels = QuickPick.labels(for: items)
        try expectEqual(labels[8], 9)
        try expect(labels[9] == nil)
        try expect(labels[11] == nil)
        try expectEqual(QuickPick.target(digit: 9, in: items)?.preview, "r9")
    }

    static func emptyListYieldsNothing() throws {
        try expectEqual(QuickPick.labels(for: []), [])
        try expect(QuickPick.target(digit: 1, in: []) == nil)
    }

    static func outOfRangeDigitsAreNil() throws {
        let items = [item("r1", pinned: false)]
        try expect(QuickPick.target(digit: 0, in: items) == nil)
        try expect(QuickPick.target(digit: -3, in: items) == nil)
        try expect(QuickPick.target(digit: 10, in: items) == nil)
    }

    /// Structural drift guard: for ANY row whose label says ⌘N, target(N)
    /// must return exactly that row's item. This is the invariant that
    /// keeps the badge, the key handler, and the menu agreeing forever.
    static func labelsAndTargetsNeverDrift() throws {
        let items = [item("pinA", pinned: true), item("r1", pinned: false),
                     item("pinB", pinned: true), item("r2", pinned: false),
                     item("r3", pinned: false), item("pinC", pinned: true),
                     item("r4", pinned: false)]
        let labels = QuickPick.labels(for: items)
        for (row, label) in labels.enumerated() {
            guard let n = label else { continue }
            try expectEqual(QuickPick.target(digit: n, in: items)?.id, items[row].id)
        }
        // and every unpinned row within budget IS labeled
        try expectEqual(labels.compactMap { $0 }, [1, 2, 3, 4])
    }

    /// The picker computes digits over the FILTERED list, so a search
    /// that hides some rows renumbers the survivors from ⌘1.
    static func filteredSubsetRenumbersFromOne() throws {
        let all = [item("apple pin", pinned: true), item("apple one", pinned: false),
                   item("banana", pinned: false), item("apple two", pinned: false)]
        let filtered = all.filter { $0.preview.contains("apple") }
        try expectEqual(QuickPick.labels(for: filtered), [nil, 1, 2])
        try expectEqual(QuickPick.target(digit: 1, in: filtered)?.preview, "apple one")
        try expectEqual(QuickPick.target(digit: 2, in: filtered)?.preview, "apple two")
    }
}
