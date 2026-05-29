// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

enum ProcessTableTests {

    static func registerAll() {
        TestRegistry.register("ProcessTable/realAppMatched", realAppMatched)
        TestRegistry.register("ProcessTable/homeApplicationsVariantMatched", homeApplicationsVariantMatched)
        TestRegistry.register("ProcessTable/shellWithPathInArgsExcluded", shellWithPathInArgsExcluded)
        TestRegistry.register("ProcessTable/grepWithPathInArgsExcluded", grepWithPathInArgsExcluded)
        TestRegistry.register("ProcessTable/tailWithPathInArgsExcluded", tailWithPathInArgsExcluded)
        TestRegistry.register("ProcessTable/ownPidExcluded", ownPidExcluded)
        TestRegistry.register("ProcessTable/multipleRealSiblingsMatched", multipleRealSiblingsMatched)
        TestRegistry.register("ProcessTable/argv0WithTrailingArgsStillMatches", argv0WithTrailingArgsStillMatches)
        TestRegistry.register("ProcessTable/headerRowSkipped", headerRowSkipped)
        TestRegistry.register("ProcessTable/leadingWhitespacePidParsed", leadingWhitespacePidParsed)
        TestRegistry.register("ProcessTable/blankAndMalformedLinesSkipped", blankAndMalformedLinesSkipped)
        TestRegistry.register("ProcessTable/emptyOutputYieldsEmpty", emptyOutputYieldsEmpty)
        TestRegistry.register("ProcessTable/unrelatedAppNotMatched", unrelatedAppNotMatched)
        TestRegistry.register("ProcessTable/realWorldBugScenarioRegressionGuard", realWorldBugScenarioRegressionGuard)
    }

    private static let bin = "/Applications/Multipaste.app/Contents/MacOS/Multipaste"

    static func realAppMatched() throws {
        let ps = "703 \(bin)"
        try expectEqual(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999), [703])
    }

    static func homeApplicationsVariantMatched() throws {
        // ~/Applications install — argv0 still ends with the suffix.
        let ps = "421 /Users/rohin/Applications/Multipaste.app/Contents/MacOS/Multipaste"
        try expectEqual(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999), [421])
    }

    static func shellWithPathInArgsExcluded() throws {
        // THE BUG: a shell that merely references the binary path in its
        // arguments must NOT be matched (its argv0 is /bin/zsh).
        let ps = "26250 /bin/zsh -c pgrep -fl Multipaste.app/Contents/MacOS/Multipaste"
        try expect(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999).isEmpty,
                   "a shell whose ARGS mention the binary path must not be treated as a Multipaste instance")
    }

    static func grepWithPathInArgsExcluded() throws {
        let ps = "40012 /usr/bin/grep -F Multipaste.app/Contents/MacOS/Multipaste"
        try expect(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999).isEmpty,
                   "grep for the path must not be matched")
    }

    static func tailWithPathInArgsExcluded() throws {
        let ps = "51234 tail -f /Applications/Multipaste.app/Contents/MacOS/Multipaste"
        try expect(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999).isEmpty,
                   "tail -f on the binary must not be matched")
    }

    static func ownPidExcluded() throws {
        let ps = "555 \(bin)"
        try expect(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 555).isEmpty,
                   "our own process must never be a 'sibling' to kill")
    }

    static func multipleRealSiblingsMatched() throws {
        let ps = """
        100 \(bin)
        200 /Users/rohin/Applications/Multipaste.app/Contents/MacOS/Multipaste
        300 /bin/zsh -c echo Multipaste.app/Contents/MacOS/Multipaste
        """
        try expectEqual(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999), [100, 200])
    }

    static func argv0WithTrailingArgsStillMatches() throws {
        let ps = "808 \(bin) --debug --verbose"
        try expectEqual(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999), [808])
    }

    static func headerRowSkipped() throws {
        // `ps -Ao pid,command` prints a "  PID COMMAND" header.
        let ps = """
          PID COMMAND
          703 \(bin)
        """
        try expectEqual(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999), [703],
                        "header row must be skipped (PID isn't an integer), real app still matched")
    }

    static func leadingWhitespacePidParsed() throws {
        // ps right-aligns pids; leading spaces must be tolerated.
        let ps = "  703 \(bin)"
        try expectEqual(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999), [703])
    }

    static func blankAndMalformedLinesSkipped() throws {
        let ps = """

        not-a-pid-line
        \(bin)
        909 \(bin)

        """
        // Line 3 has no pid prefix (just the path, no space-after-pid form
        // where the first token is a non-int) → skipped. Only 909 matches.
        try expectEqual(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999), [909])
    }

    static func emptyOutputYieldsEmpty() throws {
        try expect(ProcessTable.multipasteSiblingPIDs(psOutput: "", ownPID: 999).isEmpty)
        try expect(ProcessTable.multipasteSiblingPIDs(psOutput: "\n\n  \n", ownPID: 999).isEmpty)
    }

    static func unrelatedAppNotMatched() throws {
        let ps = "900 /Applications/SomethingElse.app/Contents/MacOS/SomethingElse"
        try expect(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999).isEmpty)
    }

    /// The exact scenario that motivated the fix: the real app plus two
    /// bystander processes that reference the binary path in their args.
    /// Only the real app's PID may be returned.
    static func realWorldBugScenarioRegressionGuard() throws {
        let ps = """
          703 \(bin)
        26250 /bin/zsh -c pgrep -fl Multipaste.app/Contents/MacOS/Multipaste
        40012 /usr/bin/grep -F Multipaste.app/Contents/MacOS/Multipaste
        """
        try expectEqual(ProcessTable.multipasteSiblingPIDs(psOutput: ps, ownPID: 999), [703],
                        "only the genuine Multipaste process is a sibling; the shell and grep are bystanders")
    }
}
