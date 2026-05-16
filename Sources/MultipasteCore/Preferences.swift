// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Set of keyboard modifiers for a global hotkey.
///
/// Raw values are bit flags chosen to be stable across versions and
/// independent of Cocoa/Carbon ordering. Conversion to AppKit/Carbon
/// happens in the app layer.
public struct HotkeyModifiers: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = HotkeyModifiers(rawValue: 1 << 0)
    public static let shift   = HotkeyModifiers(rawValue: 1 << 1)
    public static let option  = HotkeyModifiers(rawValue: 1 << 2)
    public static let control = HotkeyModifiers(rawValue: 1 << 3)
}

/// A keyboard shortcut described in a platform-neutral way.
///
/// `keyCode` is the macOS virtual key code (e.g. 9 = V), matching what
/// AppKit reports and what Carbon's `RegisterEventHotKey` expects.
public struct Hotkey: Codable, Equatable, Sendable {
    public var keyCode: Int
    public var modifiers: HotkeyModifiers
    public init(keyCode: Int, modifiers: HotkeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let `default` = Hotkey(keyCode: 9, modifiers: [.command, .shift]) // ⌘⇧V
}

/// User preferences, backed by UserDefaults.
public final class Preferences {
    private let defaults: UserDefaults

    /// Note: bounds chosen to keep both the picker UI responsive and the
    /// on-disk JSON small enough to load quickly on launch.
    public static let minHistory = 10
    public static let maxAllowedHistory = 2000

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.maxHistory:               200,
            Keys.pasteOnSelect:            true,
            Keys.launchAtLogin:            true,
            Keys.hotkeyKeyCode:            Hotkey.default.keyCode,
            Keys.hotkeyModifiers:          Hotkey.default.modifiers.rawValue,
            Keys.augmentFileCopiesWithPath: true,
        ])
    }

    public var maxHistory: Int {
        get { defaults.integer(forKey: Keys.maxHistory) }
        set {
            let clamped = min(Self.maxAllowedHistory, max(Self.minHistory, newValue))
            defaults.set(clamped, forKey: Keys.maxHistory)
        }
    }

    public var pasteOnSelect: Bool {
        get { defaults.bool(forKey: Keys.pasteOnSelect) }
        set { defaults.set(newValue, forKey: Keys.pasteOnSelect) }
    }

    public var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }

    /// Set on first successful run-through of the Welcome window. Drives
    /// whether the app shows onboarding at launch.
    public var hasCompletedFirstRun: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedFirstRun) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedFirstRun) }
    }

    /// When true, file-URL copies get the file path injected as the
    /// `.string` representation of the pasteboard so text-only paste
    /// targets (code editors, terminals) receive a path while file-URL
    /// targets (chat composers, Finder) still receive the file itself.
    /// Default on — there's no downside for normal use.
    public var augmentFileCopiesWithPath: Bool {
        get { defaults.bool(forKey: Keys.augmentFileCopiesWithPath) }
        set { defaults.set(newValue, forKey: Keys.augmentFileCopiesWithPath) }
    }

    /// When true, the picker hoists pinned items above unpinned ones
    /// (preserving relative recency within each group). Default off —
    /// recency-order is what most clipboard managers do and most users
    /// expect. Opt-in for power users who treat the pinned section as a
    /// permanent "snippets shelf."
    public var pinnedItemsFirst: Bool {
        get { defaults.bool(forKey: Keys.pinnedItemsFirst) }
        set { defaults.set(newValue, forKey: Keys.pinnedItemsFirst) }
    }

    public var hotkey: Hotkey {
        get {
            Hotkey(
                keyCode: defaults.integer(forKey: Keys.hotkeyKeyCode),
                modifiers: HotkeyModifiers(rawValue: defaults.integer(forKey: Keys.hotkeyModifiers))
            )
        }
        set {
            defaults.set(newValue.keyCode, forKey: Keys.hotkeyKeyCode)
            defaults.set(newValue.modifiers.rawValue, forKey: Keys.hotkeyModifiers)
        }
    }

    private enum Keys {
        static let maxHistory               = "maxHistory"
        static let pasteOnSelect            = "pasteOnSelect"
        static let launchAtLogin            = "launchAtLogin"
        static let hotkeyKeyCode            = "hotkey.keyCode"
        static let hotkeyModifiers          = "hotkey.modifiers"
        static let hasCompletedFirstRun     = "hasCompletedFirstRun"
        static let augmentFileCopiesWithPath = "augmentFileCopiesWithPath"
        static let pinnedItemsFirst         = "pinnedItemsFirst"
    }
}
