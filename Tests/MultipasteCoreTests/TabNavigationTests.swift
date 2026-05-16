// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

enum TabNavigationTests {

    static func registerAll() {
        TestRegistry.register("TabNavigation/nextFromSearchGoesToFirstRow", nextFromSearchGoesToFirstRow)
        TestRegistry.register("TabNavigation/nextFromSearchStaysOnEmptyList", nextFromSearchStaysOnEmptyList)
        TestRegistry.register("TabNavigation/nextAdvancesBetweenRows", nextAdvancesBetweenRows)
        TestRegistry.register("TabNavigation/nextClampsAtLastRow", nextClampsAtLastRow)
        TestRegistry.register("TabNavigation/previousFromFirstRowGoesToSearch", previousFromFirstRowGoesToSearch)
        TestRegistry.register("TabNavigation/previousBetweenRows", previousBetweenRows)
        TestRegistry.register("TabNavigation/previousFromSearchIsNoOp", previousFromSearchIsNoOp)
        TestRegistry.register("TabNavigation/singleRowRoundTrip", singleRowRoundTrip)
        TestRegistry.register("TabNavigation/threeRowSequence", threeRowSequence)
    }

    static func nextFromSearchGoesToFirstRow() throws {
        try expectEqual(
            TabNavigation.next(from: .searchField, totalRows: 5),
            .row(0)
        )
    }

    static func nextFromSearchStaysOnEmptyList() throws {
        try expectEqual(
            TabNavigation.next(from: .searchField, totalRows: 0),
            .searchField,
            "no rows to step into; Tab stays on search"
        )
    }

    static func nextAdvancesBetweenRows() throws {
        try expectEqual(
            TabNavigation.next(from: .row(2), totalRows: 5),
            .row(3)
        )
    }

    static func nextClampsAtLastRow() throws {
        try expectEqual(
            TabNavigation.next(from: .row(4), totalRows: 5),
            .row(4),
            "Tab at last row stops, doesn't wrap"
        )
    }

    static func previousFromFirstRowGoesToSearch() throws {
        try expectEqual(
            TabNavigation.previous(from: .row(0), totalRows: 5),
            .searchField
        )
    }

    static func previousBetweenRows() throws {
        try expectEqual(
            TabNavigation.previous(from: .row(3), totalRows: 5),
            .row(2)
        )
    }

    static func previousFromSearchIsNoOp() throws {
        try expectEqual(
            TabNavigation.previous(from: .searchField, totalRows: 5),
            .searchField,
            "Shift+Tab on the anchor stays on the anchor"
        )
    }

    static func singleRowRoundTrip() throws {
        // search → row(0) → row(0) (stays) → search
        var p: FocusedRegion = .searchField
        p = TabNavigation.next(from: p, totalRows: 1)
        try expectEqual(p, .row(0))
        p = TabNavigation.next(from: p, totalRows: 1)
        try expectEqual(p, .row(0), "single row: Tab again stays put")
        p = TabNavigation.previous(from: p, totalRows: 1)
        try expectEqual(p, .searchField)
    }

    static func threeRowSequence() throws {
        // search → row(0) → row(1) → row(2) → row(2) → row(1) → row(0) → search → search
        var p: FocusedRegion = .searchField
        let n = 3
        let path: [FocusedRegion] = [
            { p = TabNavigation.next(from: p, totalRows: n); return p }(),
            { p = TabNavigation.next(from: p, totalRows: n); return p }(),
            { p = TabNavigation.next(from: p, totalRows: n); return p }(),
            { p = TabNavigation.next(from: p, totalRows: n); return p }(),
            { p = TabNavigation.previous(from: p, totalRows: n); return p }(),
            { p = TabNavigation.previous(from: p, totalRows: n); return p }(),
            { p = TabNavigation.previous(from: p, totalRows: n); return p }(),
            { p = TabNavigation.previous(from: p, totalRows: n); return p }(),
        ]
        try expectEqual(path, [
            .row(0), .row(1), .row(2), .row(2),
            .row(1), .row(0), .searchField, .searchField,
        ])
    }
}
