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
