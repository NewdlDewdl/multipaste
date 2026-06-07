// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import MultipasteCore

/// Writes an item back onto the pasteboard and optionally synthesizes
/// the ⌘V keystroke so the focused app receives the paste.
enum Paster {

    /// Magic value stamped into the synthesized event's
    /// `CGEventSource.userData`. The SnippetEngine installs a session-level
    /// keyboard tap; this marker lets that tap recognize Multipaste's own
    /// synthesized keystrokes and skip them (otherwise our ⌘V could feed
    /// back into snippet matching). Value spells 'MPST', matching
    /// `HotKeyManager`'s Carbon signature.
    static let synthMarker: Int64 = 0x4D505354

    /// Replace pasteboard contents with `item`'s data. Preserves the
    /// richest representation (RTF for rich text, multiple URLs for files,
    /// raw PNG bytes for images).
    static func put(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text(let s):
            pb.setString(s, forType: .string)
        case .rtf(let rtf, let plain):
            pb.declareTypes([.rtf, .string], owner: nil)
            pb.setData(rtf, forType: .rtf)
            pb.setString(plain, forType: .string)
        case .image(let png, _, _):
            pb.declareTypes([.png, .tiff], owner: nil)
            pb.setData(png, forType: .png)
        case .fileURLs(let urls):
            pb.writeObjects(urls.map { $0 as NSURL })
        }
    }

    /// Synthesize the system-wide ⌘V keystroke into the focused app.
    /// Requires Accessibility permission; without it the events are
    /// silently dropped.
    ///
    /// Hardened in v2.2.0 (previously a bare `.maskCommand` post to the HID
    /// tap, which intermittently pasted *nothing* into Chromium/Electron
    /// apps such as Claude desktop and Codex). Three changes, each matching
    /// the long-proven Maccy/Clipy/Flycut implementations:
    ///
    ///  1. **Left-Command device bit.** The flags carry
    ///     `PasteSynthesis.commandVFlags` (generic Command mask **plus**
    ///     `NX_DEVICELCMDKEYMASK`). Chromium/Electron inspect the
    ///     device-dependent modifier bit and ignore a Command modifier that
    ///     lacks it — so the old bare-mask ⌘V degraded to a literal "v" or
    ///     was dropped. (TermiT/Flycut PR #18.)
    ///  2. **Session tap.** Posted to `.cgSessionEventTap` (where Maccy
    ///     posts) instead of `.cghidEventTap`. The HID tap is the lowest
    ///     level and the most exposed to the live hardware-modifier table;
    ///     the session tap delivers closer to the app.
    ///  3. **Local-input suppression.** `setLocalEventsFilterDuringSuppression`
    ///     keeps the user's physically-held keys (e.g. a still-down hotkey
    ///     modifier) from bleeding into the synthesized event during the
    ///     post.
    ///
    /// The source is tagged with `synthMarker` so the SnippetEngine's tap
    /// recognizes this as Multipaste's own output and lets it pass through.
    static func simulateCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        src?.userData = synthMarker
        // Suppress the user's live keyboard input for the brief post window
        // so a physically-held modifier can't merge into our ⌘V. Mouse and
        // system-defined events are still permitted; only local *keyboard*
        // events are filtered (it's the one we're not permitting).
        src?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let vKey = CGKeyCode(PasteSynthesis.vKeyCode)
        let flags = CGEventFlags(rawValue: PasteSynthesis.commandVFlags)
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
