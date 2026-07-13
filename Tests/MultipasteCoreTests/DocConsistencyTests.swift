// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

// Guards the README against the class of doc-rot that shipped through the
// v2.4.1 and v2.4.2 releases: the version bumped, VersionConsistency (which
// only checks the hero CTA / DMG link / CHANGELOG head / SECURITY major
// series) stayed green, and everything it did NOT assert silently rotted:
// the "Latest release: v2.4.1" line, six stale "310 unit tests" claims, the
// coverage-table total, and an undocumented `--pin-current` CLI flag.
//
// The cure is to anchor the human-written numbers and the documented CLI
// surface to machine-checkable ground truth:
//   - Every "N unit tests" claim and the coverage-table total must equal the
//     LIVE registered test count (`TestRegistry.cases.count`), not a
//     hard-coded literal that a test could drift alongside. This is
//     non-circular: it compares prose the human wrote against the count the
//     harness actually registered at runtime.
//   - The coverage table's per-row counts must sum to its stated total, so a
//     new suite can't be added without itemizing it.
//   - Every hidden `Multipaste --flag` handled in main.swift must be
//     documented in the README, so a new CLI surface can't ship undocumented.
enum DocConsistencyTests {

    static func registerAll() {
        TestRegistry.register("DocConsistency/statedUnitTestCountsMatchRegistry", statedUnitTestCountsMatchRegistry)
        TestRegistry.register("DocConsistency/coverageTableTotalMatchesRegistry", coverageTableTotalMatchesRegistry)
        TestRegistry.register("DocConsistency/coverageTableRowsSumToTotal", coverageTableRowsSumToTotal)
        TestRegistry.register("DocConsistency/everyHiddenCLIFlagIsDocumented", everyHiddenCLIFlagIsDocumented)
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/Tests/MultipasteCoreTests
            .deletingLastPathComponent()   // …/Tests
            .deletingLastPathComponent()   // …/<packageRoot>
    }

    private static func read(_ relativePath: String,
                             file: StaticString = #file, line: UInt = #line) throws -> String {
        let url = packageRoot.appendingPathComponent(relativePath)
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw TestFailure(message: "Failed to read \(relativePath): \(error)",
                              file: file, line: line)
        }
    }

    /// Every leading integer of every regex match, in document order.
    private static func allMatchedInts(_ pattern: String, in text: String) -> [Int] {
        var out: [Int] = []
        var search = text.startIndex..<text.endIndex
        while let r = text.range(of: pattern, options: .regularExpression, range: search) {
            let chunk = String(text[r])
            if let d = chunk.range(of: #"[0-9]+"#, options: .regularExpression) {
                out.append(Int(chunk[d]) ?? -1)
            }
            search = r.upperBound..<text.endIndex
        }
        return out
    }

    // ----- 1. "N unit tests" prose == live registered count -----

    // Historical narrative uses the bare word "tests" (e.g. "133 tests" for
    // the v2.0.0 state, "302 → 310" in a changelog line) and is intentionally
    // NOT matched here; only current-state "N unit tests" claims are pinned
    // to the live count.
    static func statedUnitTestCountsMatchRegistry() throws {
        let registry = TestRegistry.cases.count
        let readme = try read("README.md")
        let stated = allMatchedInts(#"[0-9]+ unit tests"#, in: readme)
        try expect(!stated.isEmpty,
                   "README states no \"N unit tests\" count; the badge/architecture/tests/dev lines should each say it")
        for n in stated {
            try expectEqual(n, registry,
                            "README says \"\(n) unit tests\" but the harness registered \(registry) tests; a count drifted")
        }
    }

    // ----- Coverage table helpers -----

    // Returns the contiguous block of `|`-prefixed lines that ends at the
    // "**Total**" row (the coverage table), as (dataRows, totalLine).
    private static func coverageTable(in readme: String,
                                      file: StaticString = #file, line: UInt = #line)
        throws -> (rows: [String], total: String) {
        let lines = readme.components(separatedBy: "\n")
        guard let totalIdx = lines.firstIndex(where: { $0.contains("**Total**") }) else {
            throw TestFailure(message: "README coverage table has no **Total** row", file: file, line: line)
        }
        // Walk upward while lines look like table rows.
        var start = totalIdx
        while start > 0 && lines[start - 1].hasPrefix("|") { start -= 1 }
        // block = [header, separator, data..., total]
        let block = Array(lines[start...totalIdx])
        guard block.count >= 3 else {
            throw TestFailure(message: "README coverage table is too short to parse", file: file, line: line)
        }
        let dataRows = Array(block[2..<(block.count - 1)])   // drop header + separator, and the total
        return (dataRows, block[block.count - 1])
    }

    // The count is the 2nd pipe-delimited cell of a row.
    private static func rowCount(_ row: String) -> Int? {
        let cells = row.components(separatedBy: "|")
        guard cells.count >= 3 else { return nil }
        let cell = cells[2].replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
        guard let d = cell.range(of: #"^[0-9]+"#, options: .regularExpression) else { return nil }
        return Int(cell[d])
    }

    // ----- 2. Coverage table Total == live registered count -----

    static func coverageTableTotalMatchesRegistry() throws {
        let registry = TestRegistry.cases.count
        let readme = try read("README.md")
        let (_, totalLine) = try coverageTable(in: readme)
        guard let total = rowCount(totalLine) else {
            throw TestFailure(message: "Could not parse the coverage table **Total** count from: \(totalLine)",
                              file: #file, line: #line)
        }
        try expectEqual(total, registry,
                        "README coverage table Total says \(total) but the harness registered \(registry) tests")
    }

    // ----- 3. Coverage table rows sum to its own Total -----

    static func coverageTableRowsSumToTotal() throws {
        let readme = try read("README.md")
        let (rows, totalLine) = try coverageTable(in: readme)
        guard let total = rowCount(totalLine) else {
            throw TestFailure(message: "Could not parse the coverage table **Total** count", file: #file, line: #line)
        }
        let sum = rows.compactMap(rowCount).reduce(0, +)
        try expectEqual(sum, total,
                        "README coverage table rows sum to \(sum) but the Total row says \(total); a suite row is missing or miscounted")
    }

    // ----- 4. Every hidden `--flag` in main.swift is documented in README -----

    static func everyHiddenCLIFlagIsDocumented() throws {
        let main = try read("Sources/Multipaste/main.swift")
        let readme = try read("README.md")
        // Extract each flag from `CommandLine.arguments.contains("--xxx")`.
        var flags: [String] = []
        var search = main.startIndex..<main.endIndex
        let pattern = #"CommandLine\.arguments\.contains\("(--[a-z-]+)"\)"#
        while let r = main.range(of: pattern, options: .regularExpression, range: search) {
            let chunk = String(main[r])
            if let f = chunk.range(of: #"--[a-z-]+"#, options: .regularExpression) {
                flags.append(String(chunk[f]))
            }
            search = r.upperBound..<main.endIndex
        }
        try expect(!flags.isEmpty,
                   "Expected main.swift to handle at least one hidden `--flag` (e.g. --paste-smoke)")
        let undocumented = flags.filter { !readme.contains($0) }
        try expect(undocumented.isEmpty,
                   "main.swift handles CLI flag(s) not documented in README: \(undocumented.joined(separator: ", "))")
    }
}
