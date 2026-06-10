// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

enum PreferencesTests {

    static func registerAll() {
        TestRegistry.register("Preferences/defaultsAreSensible", defaultsAreSensible)
        TestRegistry.register("Preferences/roundTripPersistence", roundTripPersistence)
        TestRegistry.register("Preferences/hotkeyEncodesAndDecodes", hotkeyEncodesAndDecodes)
        TestRegistry.register("Preferences/maxHistoryClampedToReasonableRange", maxHistoryClampedToReasonableRange)
        TestRegistry.register("Preferences/hasCompletedFirstRunDefaultsFalse", hasCompletedFirstRunDefaultsFalse)
        TestRegistry.register("Preferences/hasCompletedFirstRunPersists", hasCompletedFirstRunPersists)
        TestRegistry.register("Preferences/pinnedItemsFirstAlwaysTrueAfterDeprecation", pinnedItemsFirstAlwaysTrueAfterDeprecation)
        TestRegistry.register("Preferences/pinnedItemsFirstWritesAreNoOp", pinnedItemsFirstWritesAreNoOp)
        TestRegistry.register("Preferences/autoCopyScreenshotsDefaultsTrue", autoCopyScreenshotsDefaultsTrue)
        TestRegistry.register("Preferences/autoCopyScreenshotsPersists", autoCopyScreenshotsPersists)
        TestRegistry.register("Preferences/autoCopyScreenshotsRoundTripsOff", autoCopyScreenshotsRoundTripsOff)
        TestRegistry.register("Preferences/multiPasteSeparatorDefaultsToNewline", multiPasteSeparatorDefaultsToNewline)
        TestRegistry.register("Preferences/multiPasteSeparatorPersists", multiPasteSeparatorPersists)
        TestRegistry.register("Preferences/multiPasteSeparatorAcceptsArbitraryString", multiPasteSeparatorAcceptsArbitraryString)
    }

    private static func freshDefaults() -> UserDefaults {
        let suite = "com.rohin.multipaste.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    static func defaultsAreSensible() throws {
        let p = Preferences(defaults: freshDefaults())
        try expectEqual(p.maxHistory, 200)
        try expect(p.pasteOnSelect)
        try expect(p.launchAtLogin)
        try expectEqual(p.hotkey.keyCode, 9)
        try expect(p.hotkey.modifiers.contains(.command))
        try expect(p.hotkey.modifiers.contains(.shift))
    }

    static func roundTripPersistence() throws {
        let d = freshDefaults()
        let p1 = Preferences(defaults: d)
        p1.maxHistory = 42
        p1.pasteOnSelect = false
        let p2 = Preferences(defaults: d)
        try expectEqual(p2.maxHistory, 42)
        try expectEqual(p2.pasteOnSelect, false)
    }

    static func hotkeyEncodesAndDecodes() throws {
        let d = freshDefaults()
        let p1 = Preferences(defaults: d)
        p1.hotkey = Hotkey(keyCode: 8, modifiers: [.command, .option])
        let p2 = Preferences(defaults: d)
        try expectEqual(p2.hotkey.keyCode, 8)
        try expectEqual(p2.hotkey.modifiers, [.command, .option])
    }

    static func maxHistoryClampedToReasonableRange() throws {
        let p = Preferences(defaults: freshDefaults())
        p.maxHistory = 5
        try expectEqual(p.maxHistory, 10, "clamp lower bound to 10")
        p.maxHistory = 5000
        try expectEqual(p.maxHistory, 2000, "clamp upper bound to 2000")
    }

    static func hasCompletedFirstRunDefaultsFalse() throws {
        let p = Preferences(defaults: freshDefaults())
        try expect(!p.hasCompletedFirstRun, "fresh install must show first-run UI")
    }

    static func hasCompletedFirstRunPersists() throws {
        let d = freshDefaults()
        let p1 = Preferences(defaults: d)
        p1.hasCompletedFirstRun = true
        let p2 = Preferences(defaults: d)
        try expect(p2.hasCompletedFirstRun)
    }

    /// v2.1.1 deprecated the toggle: pinned items now ALWAYS rise
    /// to the top. The property remains in the API but is hard-wired
    /// to `true` so old plists + out-of-tree callers get the truthful
    /// answer ("yes, pinned items come first").
    @available(*, deprecated)
    static func pinnedItemsFirstAlwaysTrueAfterDeprecation() throws {
        let p = Preferences(defaults: freshDefaults())
        try expect(p.pinnedItemsFirst,
                   "after v2.1.1 the deprecated pinnedItemsFirst is always true — pinning hoists unconditionally")
    }

    /// Writes to the deprecated property must be silently ignored — we
    /// don't want a stale plist value to override the new universal
    /// behavior.
    @available(*, deprecated)
    static func pinnedItemsFirstWritesAreNoOp() throws {
        let d = freshDefaults()
        let p1 = Preferences(defaults: d)
        p1.pinnedItemsFirst = false  // attempted disable
        try expect(p1.pinnedItemsFirst,
                   "writes must be no-ops post-deprecation; the getter still returns true")
        // And across re-instantiation, still true (the no-op write
        // didn't sneak the value into UserDefaults under a different key).
        let p2 = Preferences(defaults: d)
        try expect(p2.pinnedItemsFirst)
    }

    static func autoCopyScreenshotsDefaultsTrue() throws {
        let p = Preferences(defaults: freshDefaults())
        try expect(p.autoCopyScreenshots,
                   "auto-copy screenshots must default ON — the feature is the value prop")
    }

    static func autoCopyScreenshotsPersists() throws {
        let d = freshDefaults()
        let p1 = Preferences(defaults: d)
        p1.autoCopyScreenshots = false
        let p2 = Preferences(defaults: d)
        try expect(!p2.autoCopyScreenshots,
                   "opting out must survive across app launches")
    }

    static func autoCopyScreenshotsRoundTripsOff() throws {
        // Catch any "did you spell the key the same way in get vs set?" bug.
        let d = freshDefaults()
        let p1 = Preferences(defaults: d)
        p1.autoCopyScreenshots = false
        try expect(!p1.autoCopyScreenshots)
        p1.autoCopyScreenshots = true
        try expect(p1.autoCopyScreenshots)
        let p2 = Preferences(defaults: d)
        try expect(p2.autoCopyScreenshots)
    }

    static func multiPasteSeparatorDefaultsToNewline() throws {
        let p = Preferences(defaults: freshDefaults())
        try expectEqual(p.multiPasteSeparator, "\n",
                        "fresh install joins combined multi-pastes one-item-per-line")
    }

    static func multiPasteSeparatorPersists() throws {
        let d = freshDefaults()
        let p1 = Preferences(defaults: d)
        p1.multiPasteSeparator = "\t"
        let p2 = Preferences(defaults: d)
        try expectEqual(p2.multiPasteSeparator, "\t")
    }

    /// The pref stores a raw literal, deliberately unvalidated: a power
    /// user can `defaults write` any separator (" · ", ", ", "; ") and
    /// the composer will honor it even though the Settings popup has no
    /// matching row.
    static func multiPasteSeparatorAcceptsArbitraryString() throws {
        let d = freshDefaults()
        let p1 = Preferences(defaults: d)
        p1.multiPasteSeparator = " · "
        try expectEqual(p1.multiPasteSeparator, " · ")
        let p2 = Preferences(defaults: d)
        try expectEqual(p2.multiPasteSeparator, " · ")
    }
}
