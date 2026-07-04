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
            Keys.autoCopyScreenshots:      true,
            Keys.multiPasteSeparator:      MultiPasteSeparatorChoice.newline.literal,
            Keys.plainTextPasteDefault:    false,
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

    /// **Deprecated in v2.1.1 — pinned items are unconditionally
    /// hoisted to the top of the picker now.** Reads always return
    /// `true`; writes are silently ignored. The property is kept in
    /// the public API so old plists with `pinnedItemsFirst` set
    /// don't trigger decode warnings, and any out-of-tree code that
    /// reads it gets the truthful answer ("yes, pinned items come
    /// first").
    ///
    /// Why removed: the toggle defaulted to off, which meant the pin
    /// button was a no-op in the visible UI — items you'd pinned still
    /// got pushed down the picker as new content was copied. Rohin
    /// reported this with a screenshot. Pinning now means both "show
    /// me first" AND "survive eviction," not just the latter.
    @available(*, deprecated, message: "Pinned items are always hoisted to the top in v2.1.1+. This property always returns true and ignores writes.")
    public var pinnedItemsFirst: Bool {
        get { true }
        set { /* no-op: see deprecation message */ }
    }

    /// When true, files saved by macOS's `screencapture` to the user's
    /// configured screenshot location are auto-copied to the clipboard
    /// the moment they appear on disk. Default ON: that's the whole
    /// point of the feature — most users never remember to hold ⌃ to
    /// get a screenshot on the clipboard, so they screenshot, then
    /// drag the file to chat, instead of just ⌘V. With this on, every
    /// screenshot is one ⌘V away.
    public var autoCopyScreenshots: Bool {
        get { defaults.bool(forKey: Keys.autoCopyScreenshots) }
        set { defaults.set(newValue, forKey: Keys.autoCopyScreenshots) }
    }

    /// Separator placed between items when a multi-paste combines into
    /// a single text paste (mark items with ⌥↩ in the picker, then ↩).
    /// Stored as the literal string so the composer just uses it as-is;
    /// the Settings popup maps it to `MultiPasteSeparatorChoice`.
    /// Default: newline, one item per line.
    public var multiPasteSeparator: String {
        get { defaults.string(forKey: Keys.multiPasteSeparator) ?? MultiPasteSeparatorChoice.newline.literal }
        set { defaults.set(newValue, forKey: Keys.multiPasteSeparator) }
    }

    /// When true, a bare `↩` in the picker pastes the item as **plain
    /// text** (formatting stripped) and `⇧↩` pastes it rich — i.e. the
    /// default flips and Shift inverts. When false (the default, matching
    /// pre-v2.4.0 behavior), `↩` pastes rich and `⇧↩` pastes plain. The
    /// picker's `⌘1–9` quick-pick and the menu-bar Recent quick-pick use
    /// the base flavor this preference selects (no Shift inversion there).
    /// Snippet expansion always pastes rich — a snippet's formatting is
    /// part of what the user saved.
    ///
    /// Off by default so existing users' muscle memory (`↩` = paste what I
    /// copied, formatting and all) is unchanged; plain text is always one
    /// `⇧↩` away regardless of this setting. The flavor resolution itself
    /// is `PasteFlavor.effective(plainTextPasteDefault:shiftPressed:)`.
    public var plainTextPasteDefault: Bool {
        get { defaults.bool(forKey: Keys.plainTextPasteDefault) }
        set { defaults.set(newValue, forKey: Keys.plainTextPasteDefault) }
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
        static let autoCopyScreenshots      = "autoCopyScreenshots"
        static let multiPasteSeparator      = "multiPasteSeparator"
        static let plainTextPasteDefault    = "plainTextPasteDefault"
    }
}
