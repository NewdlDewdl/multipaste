// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit

/// Ensures only one Multipaste instance is alive at a time. Without this,
/// the LaunchAgent and the SMAppService Login Item can both spawn a
/// daemon — two processes polling the same clipboard, fighting over the
/// same history JSON.
///
/// Strategy: at launch, find any other process whose path matches our
/// installed-bundle binary. Send the older one SIGTERM. If we're the
/// older one ourselves, exit immediately and let the newer instance
/// take over.
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
        var siblings: [Int32] = []
        for line in text.split(separator: "\n") {
            guard line.contains("Multipaste.app/Contents/MacOS/Multipaste") else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let firstSpace = trimmed.firstIndex(of: " ") ?? trimmed.endIndex
            if let pid = Int32(trimmed[..<firstSpace]), pid != me {
                siblings.append(pid)
            }
        }
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
