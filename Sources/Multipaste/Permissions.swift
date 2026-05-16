// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import ApplicationServices

enum Permissions {

    /// True if Multipaste.app has been added to System Settings → Privacy
    /// & Security → Accessibility and toggled on. Required for paste
    /// keystroke synthesis.
    static var isTrustedForAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// Trigger the system "you need to grant Accessibility access" prompt
    /// and return whether the process is already trusted.
    @discardableResult
    static func promptForAccessibility() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts: [CFString: Any] = [key: kCFBooleanTrue!]
        return AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    /// Wipe Multipaste's Accessibility TCC entry so the user can re-grant
    /// from scratch. Useful when a previous grant became stale (typical
    /// after an update changed the cdhash and TCC indexes by cdhash).
    /// Uses `/usr/bin/tccutil` rather than the Homebrew Python wrapper,
    /// which is broken on Python 3.14.
    ///
    /// Output is drained via `readabilityHandler` rather than the naive
    /// `waitUntilExit` + `readDataToEndOfFile` sequence. tccutil's
    /// output is short in practice (one or two lines) so the bug would
    /// never trip — but the pattern was the same shape as three other
    /// occurrences of the deadlock bug in this codebase, so we use the
    /// safe pattern everywhere as a matter of discipline.
    @discardableResult
    static func resetAccessibilityPermission() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "Accessibility", "com.rohin.multipaste"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        var collected = Data()
        let group = DispatchGroup()
        group.enter()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                group.leave()
            } else {
                collected.append(chunk)
            }
        }
        do {
            try task.run()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            return error.localizedDescription
        }
        task.waitUntilExit()
        _ = group.wait(timeout: .now() + .seconds(3))
        let out = String(data: collected, encoding: .utf8) ?? ""
        return task.terminationStatus == 0 ? nil : out
    }

    /// One-call helper: trigger the system add-to-list prompt AND open
    /// System Settings straight to the Accessibility pane AND show a
    /// step-by-step alert. This is the canonical "Grant Accessibility"
    /// action — called from the menu bar, Welcome window, and the
    /// post-pick fallback when auto-paste is denied.
    static func walkUserThroughAccessibilityGrant() {
        // The prompt+list-add side effect of this call is what we want:
        // even when isTrusted, calling with prompt=true is a no-op (no
        // dialog appears). On first call, macOS adds Multipaste to the
        // Accessibility list and shows its own dialog.
        promptForAccessibility()

        // Deep-link System Settings → Privacy & Security → Accessibility.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
