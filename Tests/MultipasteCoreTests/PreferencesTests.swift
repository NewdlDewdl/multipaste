import Foundation
@testable import MultipasteCore

enum PreferencesTests {

    static func registerAll() {
        TestRegistry.register("Preferences/defaultsAreSensible", defaultsAreSensible)
        TestRegistry.register("Preferences/roundTripPersistence", roundTripPersistence)
        TestRegistry.register("Preferences/hotkeyEncodesAndDecodes", hotkeyEncodesAndDecodes)
        TestRegistry.register("Preferences/maxHistoryClampedToReasonableRange", maxHistoryClampedToReasonableRange)
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
}
