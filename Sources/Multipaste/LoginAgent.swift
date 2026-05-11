import Foundation

/// Thin wrapper over `launchctl enable/disable` for our LaunchAgent label.
///
/// We don't use `SMAppService.loginItem` because the agent is what
/// supervises the daemon (restart on crash, log capture). Toggling its
/// enabled bit via `launchctl` keeps the agent as the single source of
/// truth for "should this run at login?".
enum LoginAgent {

    static let label = "com.rohin.multipaste"

    static func setEnabled(_ enabled: Bool) {
        let uid = String(getuid())
        let target = "gui/\(uid)/\(label)"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = enabled ? ["enable", target] : ["disable", target]
        // Discard stdout/stderr; we don't surface launchctl errors here
        // (the most common failure is "no such service" if the user hasn't
        // installed via install.sh — fine, they'll never see this UI).
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do { try task.run(); task.waitUntilExit() } catch { /* best effort */ }
    }
}
