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
    @discardableResult
    static func enforce() -> Bool {
        let me = ProcessInfo.processInfo.processIdentifier
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-Ao", "pid,lstart,command"]
        let pipe = Pipe()
        task.standardOutput = pipe
        do { try task.run(); task.waitUntilExit() } catch { return true }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
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
