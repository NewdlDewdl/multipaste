// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import MultipasteCore

/// Ensures only one Multipaste instance is alive at a time. Without this,
/// the LaunchAgent and the SMAppService Login Item can both spawn a
/// daemon — two processes polling the same clipboard, fighting over the
/// same history JSON.
///
/// Strategy: at launch, find any other process whose **executable** is
/// our installed-bundle binary and SIGTERM it, then stay alive.
///
/// Matching is delegated to `ProcessTable.multipasteSiblingPIDs`, which
/// keys on `argv0` (the executable), NOT on whether the whole command
/// line contains the binary path. The earlier `line.contains(...)`
/// approach matched any bystander process that merely *mentioned* the
/// path in its arguments (a `grep`, a `tail -f`, an editor, a shell
/// one-liner) and SIGTERM'd it on every launch. Fixed in v2.1.2.
enum SingleInstance {

    /// Returns true if we should keep running, false if we should exit
    /// because a newer Multipaste instance is already running.
    ///
    /// CRITICAL: we drain the pipe ASYNCHRONOUSLY before `waitUntilExit`.
    /// `ps -Ao` on a busy macOS system easily exceeds the 64 KB pipe
    /// buffer, and the naive `waitUntilExit` + `readDataToEndOfFile`
    /// pattern deadlocks: ps blocks writing, we block waiting for ps to
    /// exit. v1.6.0 shipped with that deadlock and the entire app froze
    /// at `main.swift` line 9 — no menu-bar icon, no Welcome window, no
    /// anything. Same fix as Diagnostics.readCodesign.
    @discardableResult
    static func enforce() -> Bool {
        let me = ProcessInfo.processInfo.processIdentifier
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-Ao", "pid,command"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

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
        do { try task.run() } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            return true
        }
        task.waitUntilExit()
        _ = group.wait(timeout: .now() + .seconds(3))

        let text = String(data: collected, encoding: .utf8) ?? ""
        // Match on argv0 (the executable), not a substring of the whole
        // command line — see ProcessTable for the bug this prevents.
        let siblings = ProcessTable.multipasteSiblingPIDs(psOutput: text, ownPID: me)
        if siblings.isEmpty { return true }

        // Two processes — we're the newer one. Kill the older sibling(s)
        // and stay alive.
        for pid in siblings {
            kill(pid, SIGTERM)
            FileHandle.standardError.write(Data(
                "[multipaste] terminating stale sibling pid=\(pid)\n".utf8
            ))
        }
        return true
    }
}
