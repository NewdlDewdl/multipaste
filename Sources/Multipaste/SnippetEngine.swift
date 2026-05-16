// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import Carbon.HIToolbox
import MultipasteCore

/// Watches the system keyboard stream and expands snippet triggers in any
/// app. Uses `CGEvent.tapCreate` at the session level.
///
/// Privacy & safety:
///   - We listen at `cgSessionEventTap` (per-session) rather than the HID
///     tap, so per-user TCC applies. Requires Accessibility consent —
///     same prompt as `Paster.simulateCommandV()`. Without consent the
///     tap silently won't install and the engine becomes a no-op.
///   - We mark our own synthesized backspaces and ⌘V with a sentinel
///     `userData` so the tap recognizes them and never expands its own
///     output (would otherwise loop into oblivion).
///   - Triggers ONLY fire on pinned items with a non-empty `trigger`.
///   - The buffer is a bounded sliding window (64 chars) and gets reset
///     by every modifier-bearing key, the Esc key, and after a successful
///     expansion. Keystrokes themselves are NEVER persisted to disk.
final class SnippetEngine {

    /// Magic value placed in `CGEventSource.userData` for events we
    /// generate ourselves. Mirrors HotKeyManager's signature ('MPST').
    static let synthMarker: Int64 = 0x4D505354

    private let store: HistoryStore
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer: String = ""
    private let maxBuffer = 64

    init(store: HistoryStore) {
        self.store = store
    }

    /// Returns true if the tap installed successfully. Returns false (and
    /// the engine becomes a no-op) if the process lacks Accessibility
    /// permission. Safe to call again later once permission is granted.
    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = (1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<SnippetEngine>.fromOpaque(refcon).takeUnretainedValue()
                return engine.handle(type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        buffer = ""
    }

    // MARK: - Tap callback

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // If macOS disabled our tap (timeout or user input), re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        // Skip events we synthesized ourselves
        let marker = event.getIntegerValueField(.eventSourceUserData)
        if marker == Self.synthMarker { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Reset buffer on Cmd/Ctrl/Esc — these denote command actions or
        // a clear pivot point in the user's intent.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            buffer = ""
            return Unmanaged.passUnretained(event)
        }
        if keyCode == 53 { // esc
            buffer = ""
            return Unmanaged.passUnretained(event)
        }
        if keyCode == 51 { // delete/backspace
            if !buffer.isEmpty { buffer.removeLast() }
            return Unmanaged.passUnretained(event)
        }

        // Resolve the keystroke to a Unicode string
        var charCount: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4,
                                       actualStringLength: &charCount,
                                       unicodeString: &chars)
        let typed = String(utf16CodeUnits: chars, count: charCount)
        guard !typed.isEmpty else { return Unmanaged.passUnretained(event) }

        // Carbon's Return key reports as "\r" via keyboardGetUnicodeString,
        // which is fine — Matcher treats \r as a terminator too.
        buffer.append(typed)
        if buffer.count > maxBuffer {
            buffer = String(buffer.suffix(maxBuffer))
        }

        if let m = SnippetMatcher.match(buffer: buffer, snippets: store.snippets) {
            buffer = ""
            // Defer the actual key synthesis to the main runloop so this
            // callback returns quickly — taps must not block.
            let charsToDelete = m.charsToDelete
            let item = m.snippet
            DispatchQueue.main.async { [weak self] in
                self?.expand(item: item, deleting: charsToDelete)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Expansion

    private func expand(item: ClipboardItem, deleting: Int) {
        // Send backspaces to remove the trigger + terminator the user typed.
        for _ in 0..<deleting { sendBackspace() }
        // Briefly wait so the target app applies the deletes before paste.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(20)) {
            Paster.put(item)
            self.sendCommandV()
        }
    }

    private func source() -> CGEventSource? {
        let src = CGEventSource(stateID: .combinedSessionState)
        src?.userData = Self.synthMarker
        return src
    }

    private func sendBackspace() {
        let src = source()
        let down = CGEvent(keyboardEventSource: src, virtualKey: 51, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: 51, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func sendCommandV() {
        let src = source()
        let down = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
