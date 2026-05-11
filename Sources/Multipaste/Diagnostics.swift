import AppKit
import ApplicationServices
import MultipasteCore

/// Internal-state inspector. Gives the user (and us) a one-screen view of
/// what Multipaste actually thinks is true at this moment: trust state,
/// code-signing identity, bundle location, sibling processes, supervisor
/// status. The first place to look when something feels off.
enum Diagnostics {

    struct Snapshot {
        let version: String
        let bundlePath: String
        let executablePath: String
        let pid: Int32
        let accessibilityGranted: Bool
        let cdhashShort: String
        let cdhashFull: String
        let signingIdentifier: String
        let designatedRequirement: String
        let launchAgentInstalled: Bool
        let loginItemStatus: String
        let siblingMultipasteProcesses: [Int32]
        let timestamp: Date
    }

    static func snapshot() -> Snapshot {
        let bundle = Bundle.main.bundlePath
        let exe = Bundle.main.executablePath ?? "?"
        let cs = readCodesign(bundle: bundle)
        let supervisor = supervisorState()

        return Snapshot(
            version: MultipasteVersion.value,
            bundlePath: bundle,
            executablePath: exe,
            pid: ProcessInfo.processInfo.processIdentifier,
            accessibilityGranted: AXIsProcessTrusted(),
            cdhashShort: cs.cdhashShort,
            cdhashFull: cs.cdhashFull,
            signingIdentifier: cs.identifier,
            designatedRequirement: cs.designatedRequirement,
            launchAgentInstalled: supervisor.launchAgent,
            loginItemStatus: supervisor.loginItem,
            siblingMultipasteProcesses: siblingMultipasteProcesses(),
            timestamp: Date()
        )
    }

    static func summary(_ s: Snapshot) -> String {
        let ax = s.accessibilityGranted ? "ON \u{2705}" : "OFF \u{26A0}\u{FE0F}"
        let siblings = s.siblingMultipasteProcesses.isEmpty
            ? "none \u{2705}"
            : s.siblingMultipasteProcesses.map(String.init).joined(separator: ", ") + " \u{26A0}\u{FE0F}"
        return """
        Multipaste \(s.version)
        Captured: \(ISO8601DateFormatter().string(from: s.timestamp))

        Accessibility access:    \(ax)
        Process ID:              \(s.pid)
        Other Multipaste PIDs:   \(siblings)

        Bundle path:             \(s.bundlePath)
        Executable:              \(s.executablePath)

        Signing identifier:      \(s.signingIdentifier)
        Designated requirement:  \(s.designatedRequirement)
        Code directory hash:     \(s.cdhashShort)

        LaunchAgent installed:   \(s.launchAgentInstalled ? "yes" : "no")
        Login item status:       \(s.loginItemStatus)
        """
    }

    /// Append a one-line summary of boot state to BOTH stderr and a
    /// known log file. The known file is necessary because SMAppService-
    /// launched processes don't get a `StandardErrorPath` redirect the
    /// way LaunchAgent-launched processes did, so writing only to
    /// stderr would scatter the output across Console.app entries.
    ///
    /// Kept deliberately subprocess-free: invoking `codesign` here led
    /// to a `waitUntilExit()`/pipe-drain deadlock in v1.6.0-rc1 when
    /// codesign output exceeded the pipe buffer. Full snapshot is
    /// available on-demand via the Diagnostics… menu item.
    static func logBoot() {
        let trust = AXIsProcessTrusted()
        let pid = ProcessInfo.processInfo.processIdentifier
        let bundle = Bundle.main.bundlePath
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(stamp)] [multipaste \(MultipasteVersion.value) pid=\(pid)] " +
            "trust=\(trust ? "ON" : "OFF") " +
            "bundle=\(bundle)"
        write(line: line)
    }

    /// Append an arbitrary line to the known log file. Used by event-
    /// driven things like the permission-monitor transition.
    static func log(_ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        write(line: "[\(stamp)] [multipaste \(MultipasteVersion.value) pid=\(ProcessInfo.processInfo.processIdentifier)] \(message)")
    }

    /// Path to the log file. Public so users (and `tail`) can find it.
    static var logURL: URL {
        let base = (try? FileManager.default.url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )) ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library")
        return base.appendingPathComponent("Logs/Multipaste/multipaste.log")
    }

    private static func write(line: String) {
        let data = Data((line + "\n").utf8)
        // stderr — caught by terminal launches and by anyone listening
        // via Console.app subsystem filter.
        FileHandle.standardError.write(data)

        // File — guaranteed location regardless of launch context.
        let url = logURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        if let fh = try? FileHandle(forWritingTo: url) {
            defer { try? fh.close() }
            try? fh.seekToEnd()
            try? fh.write(contentsOf: data)
        }
    }

    // MARK: - Private

    private static func readCodesign(bundle: String) -> (cdhashShort: String, cdhashFull: String, identifier: String, designatedRequirement: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-d", "--verbose=4", "-r-", bundle]
        let out = Pipe()
        task.standardError = out
        task.standardOutput = out
        // CRITICAL: read the pipe asynchronously to avoid the classic
        // deadlock where the child blocks writing to a full pipe while
        // we block in waitUntilExit. We drain into a Data accumulator
        // on a DispatchIO/Stream callback, then wait.
        var collected = Data()
        let group = DispatchGroup()
        group.enter()
        out.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                group.leave()
            } else {
                collected.append(chunk)
            }
        }
        do { try task.run() } catch {
            out.fileHandleForReading.readabilityHandler = nil
            return ("?", "?", "?", "?")
        }
        task.waitUntilExit()
        // Give the readability handler a beat to drain residual bytes
        // and call group.leave on EOF.
        _ = group.wait(timeout: .now() + .seconds(2))
        let text = String(data: collected, encoding: .utf8) ?? ""

        var cdhashShort = "?"
        var cdhashFull = "?"
        var identifier = "?"
        var designated = "?"
        for line in text.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("CDHash=") {
                cdhashShort = String(s.dropFirst("CDHash=".count))
            }
            if s.hasPrefix("CandidateCDHashFull sha256=") {
                cdhashFull = String(s.dropFirst("CandidateCDHashFull sha256=".count))
            }
            if s.hasPrefix("Identifier=") {
                identifier = String(s.dropFirst("Identifier=".count))
            }
            if s.hasPrefix("designated => ") {
                designated = String(s.dropFirst("designated => ".count))
            }
        }
        return (cdhashShort, cdhashFull, identifier, designated)
    }

    private static func siblingMultipasteProcesses() -> [Int32] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-Ao", "pid,command"]
        let out = Pipe()
        task.standardOutput = out
        try? task.run()
        task.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        let myPid = ProcessInfo.processInfo.processIdentifier
        var result: [Int32] = []
        for line in text.split(separator: "\n") {
            // Match our binary path. We deliberately match only the
            // installed-bundle path so dev `swift run` instances don't
            // count as siblings.
            guard line.contains("Multipaste.app/Contents/MacOS/Multipaste") else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let firstSpace = trimmed.firstIndex(of: " ") ?? trimmed.endIndex
            if let pid = Int32(trimmed[..<firstSpace]), pid != myPid {
                result.append(pid)
            }
        }
        return result
    }

    private struct SupervisorState { let launchAgent: Bool; let loginItem: String }

    private static func supervisorState() -> SupervisorState {
        let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/com.rohin.multipaste.plist"
        let agent = FileManager.default.fileExists(atPath: plistPath)

        let loginItem: String
        if #available(macOS 13.0, *) {
            switch SMAppServiceStatusProbe.status() {
            case .enabled:            loginItem = "enabled"
            case .notRegistered:      loginItem = "not registered"
            case .notFound:           loginItem = "not found"
            case .requiresApproval:   loginItem = "needs approval"
            case .unknown:            loginItem = "unknown"
            }
        } else {
            loginItem = "n/a (macOS < 13)"
        }
        return SupervisorState(launchAgent: agent, loginItem: loginItem)
    }
}

/// Tiny indirection so Diagnostics can read SMAppService without importing
/// ServiceManagement at the top level (keeps Diagnostics file portable).
enum SMAppServiceStatusProbe {
    static func status() -> LoginItem.Status { LoginItem.status }
}
