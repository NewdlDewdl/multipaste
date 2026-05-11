import AppKit
import ServiceManagement

/// Modern "open at login" support via `SMAppService.mainApp` (macOS 13+).
///
/// Registering the main app as a login item surfaces in
/// System Settings → General → Login Items where users actually look.
/// No LaunchAgent plist, no Terminal, no launchctl. The `register()` call
/// requires the bundle to live in `/Applications` or `~/Applications`;
/// running from `~/Downloads` will throw `notFoundForBundle`.
enum LoginItem {

    enum Status: String {
        case enabled, notRegistered, notFound, requiresApproval, unknown
    }

    static var status: Status {
        guard #available(macOS 13.0, *) else { return .unknown }
        switch SMAppService.mainApp.status {
        case .enabled:            return .enabled
        case .notRegistered:      return .notRegistered
        case .notFound:           return .notFound
        case .requiresApproval:   return .requiresApproval
        @unknown default:         return .unknown
        }
    }

    /// Register the current bundle as a login item. Safe to call repeatedly.
    /// Returns nil on success or an error string on failure (for surfacing
    /// in the Welcome window).
    @discardableResult
    static func enable() -> String? {
        guard #available(macOS 13.0, *) else {
            return "macOS 13 or later is required."
        }
        do {
            try SMAppService.mainApp.register()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    @discardableResult
    static func disable() -> String? {
        guard #available(macOS 13.0, *) else { return nil }
        do {
            try SMAppService.mainApp.unregister()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static var isEnabled: Bool { status == .enabled }
}
