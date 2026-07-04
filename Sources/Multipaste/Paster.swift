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

    /// Replace pasteboard contents with `item`'s data in the requested
    /// `flavor`.
    ///
    /// - `.rich` (default) preserves the richest representation: RTF for rich
    ///   text, multiple URLs for files, raw PNG bytes for images. Byte-for-byte
    ///   the pre-v2.4.0 behavior; every existing caller is unaffected.
    /// - `.plainText` strips formatting: rich text drops its `.rtf` and
    ///   pastes only the plain string; a file copy pastes its path text; an
    ///   image (which has no plain form) falls back to the rich image write.
    ///
    /// The *decision* (which pasteboard types to declare and what bytes they
    /// carry) lives in the pure, unit-tested `PlainText.pasteWrite`; this
    /// method is just the `NSPasteboard` executor. `pasteboard` is injectable
    /// so the `--paste-smoke` self-check (`PasteSmokeCheck`, run by
    /// `make plaintext-smoke-test`) can assert THIS method's writes against
    /// a private pasteboard; that's the executor's direct coverage, since
    /// unit tests can't import the executable target.
    static func put(_ item: ClipboardItem,
                    flavor: PasteFlavor = .rich,
                    to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        switch PlainText.pasteWrite(for: item, flavor: flavor) {
        case .string(let s):
            pasteboard.setString(s, forType: .string)
        case .richText(let rtf, let plain):
            pasteboard.declareTypes([.rtf, .string], owner: nil)
            pasteboard.setData(rtf, forType: .rtf)
            pasteboard.setString(plain, forType: .string)
        case .image(let png):
            pasteboard.declareTypes([.png, .tiff], owner: nil)
            pasteboard.setData(png, forType: .png)
        case .fileURLs(let urls):
            pasteboard.writeObjects(urls.map { $0 as NSURL })
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
