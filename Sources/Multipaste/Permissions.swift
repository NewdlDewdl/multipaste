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
}
