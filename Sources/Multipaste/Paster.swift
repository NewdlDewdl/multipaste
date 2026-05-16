// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import MultipasteCore

/// Writes an item back onto the pasteboard and optionally synthesizes
/// the ⌘V keystroke so the focused app receives the paste.
enum Paster {

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

    /// Synthesize the system-wide ⌘V keystroke. Requires Accessibility
    /// permission; without it the events are silently dropped.
    static func simulateCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9 // virtual keycode for "v"
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
