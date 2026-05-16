// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

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
        // launchctl enable/disable produce a single line at most. Route
        // straight to /dev/null instead of a Pipe() we never drain —
        // safer than the previous "unread pipe" pattern, which can fill
        // if launchctl ever decides to be chatty in a future macOS.
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do { try task.run(); task.waitUntilExit() } catch { /* best effort */ }
    }
}
