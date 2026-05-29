// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Pure parsing of `ps -Ao pid,command` output for the single-instance
/// guard.
///
/// ## The bug this fixes (v2.1.2)
///
/// `SingleInstance.enforce()` used to decide which processes were rival
/// Multipaste instances with:
///
/// ```swift
/// guard line.contains("Multipaste.app/Contents/MacOS/Multipaste") else { continue }
/// ```
///
/// That matches the substring **anywhere on the line** — including the
/// *arguments* of unrelated processes. A shell running
/// `zsh -c 'pgrep -f .../MacOS/Multipaste'`, a `grep` for that path, a
/// `tail -f` on the app binary, or an editor with the file open all have
/// the path in their command line, so `enforce()` would SIGTERM them on
/// every Multipaste launch. (It repeatedly killed the diagnostic shell
/// used while investigating an unrelated issue — that's how it was
/// found.)
///
/// The correct signal is the process's **executable** — `argv0`, the
/// first whitespace-delimited token of the `command` column — not the
/// whole command line. A real Multipaste process has
/// `argv0 == /Applications/Multipaste.app/Contents/MacOS/Multipaste`
/// (or the `~/Applications` variant). A bystander shell has
/// `argv0 == /bin/zsh` and merely mentions the path in later tokens.
public enum ProcessTable {

    /// The canonical trailing path of the Multipaste app's executable,
    /// matched against `argv0`. Works for both `/Applications` and
    /// `~/Applications` installs (both end with this suffix).
    public static let multipasteBinarySuffix = "Multipaste.app/Contents/MacOS/Multipaste"

    /// Parse `ps -Ao pid,command` output and return the PIDs of *actual*
    /// Multipaste app processes — those whose `argv0` (executable) is the
    /// Multipaste binary — excluding `ownPID`.
    ///
    /// - Matches on `argv0`, never on the full command line, so bystander
    ///   processes that merely reference the binary path in their
    ///   arguments are NOT matched.
    /// - Tolerates leading whitespace, the `ps` header row (`PID COMMAND`),
    ///   blank lines, and malformed rows (all skipped).
    /// - Tolerates the real binary being invoked with trailing arguments
    ///   (`…/Multipaste --debug`) — `argv0` still ends with the suffix.
    public static func multipasteSiblingPIDs(
        psOutput: String,
        ownPID: Int32,
        binarySuffix: String = multipasteBinarySuffix
    ) -> [Int32] {
        var pids: [Int32] = []
        for rawLine in psOutput.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let firstSpace = line.firstIndex(of: " ") else { continue }

            let pidField = line[..<firstSpace]
            guard let pid = Int32(pidField) else { continue }   // header / malformed → skip

            let commandColumn = line[line.index(after: firstSpace)...]
                .trimmingCharacters(in: .whitespaces)
            // argv0 = the executable path = first token of the command column.
            let argv0 = commandColumn
                .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                .first
                .map(String.init) ?? ""

            guard !argv0.isEmpty else { continue }
            guard argv0.hasSuffix(binarySuffix) else { continue }
            guard pid != ownPID else { continue }
            pids.append(pid)
        }
        return pids
    }
}
