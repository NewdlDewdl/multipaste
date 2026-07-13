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
        TestRegistry.register("DocConsistency/coverageRowCountsMatchPerSuiteRegistry", coverageRowCountsMatchPerSuiteRegistry)
        TestRegistry.register("DocConsistency/everyCanonicalDocRelativeLinkResolves", everyCanonicalDocRelativeLinkResolves)
        TestRegistry.register("DocConsistency/filesTreeTestAndSuiteCountsMatchRegistry", filesTreeTestAndSuiteCountsMatchRegistry)
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

    // The registry names every case `Suite/testName`; the suite is the part
    // before the first slash. Verified universal: zero slashless registrations.
    private static func suitePrefix(of name: String) -> String {
        String(name.prefix(while: { $0 != "/" }))
    }

    /// Live count of registered cases per suite, tallied from the registry.
    private static func perSuiteRegistryCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for c in TestRegistry.cases {
            counts[suitePrefix(of: c.name), default: 0] += 1
        }
        return counts
    }

    /// The first backticked identifier in a coverage row's suite cell
    /// (cells[1]); e.g. "`HistoryStore` (pin/unpin order)" -> "HistoryStore".
    private static func rowSuitePrefix(_ row: String) -> String? {
        let cells = row.components(separatedBy: "|")
        guard cells.count >= 2 else { return nil }
        guard let r = cells[1].range(of: #"`[A-Za-z0-9]+`"#, options: .regularExpression) else { return nil }
        return String(cells[1][r].dropFirst().dropLast())
    }

    /// True if `index` sits inside a single-backtick inline-code span on its
    /// own line: prose ABOUT link syntax (a literal `[a](b)`) must not be read
    /// as a rendered link. Uses the odd-backtick-count rule (an odd number of
    /// backticks between the line start and `index` means the position is
    /// inside an open span). Strictly more robust than checking the characters
    /// flanking the match, which misses a `](x)` wrapped in a larger code span
    /// (e.g. CHANGELOG's `` `[link](url)` ``).
    private static func isInsideInlineCode(_ index: String.Index, in text: String) -> Bool {
        let lineStart = text[..<index].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let ticks = text[lineStart..<index].reduce(0) { $0 + ($1 == "`" ? 1 : 0) }
        return ticks % 2 == 1
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

    // ----- 5. Each coverage row's count == the live per-suite count -----

    // Strictly stronger than coverageTableRowsSumToTotal: that guard only
    // pins the GLOBAL sum, so one suite could be over-counted while another is
    // under-counted and the total still balances. This pins EVERY suite. It
    // also makes a missing suite row (a new suite added without itemizing it)
    // or a stale/renamed row (a suite dropped from the registry but left in
    // the table) fail loudly, because the row-prefix set must equal the live
    // suite set. Non-circular: the human-written rows are compared against the
    // `Suite/test` prefixes the harness actually registered at runtime.
    static func coverageRowCountsMatchPerSuiteRegistry() throws {
        let readme = try read("README.md")
        let (rows, _) = try coverageTable(in: readme)
        let live = perSuiteRegistryCounts()
        try expect(!live.isEmpty, "registry registered zero suites")

        var coverage: [String: Int] = [:]
        for row in rows {
            guard let prefix = rowSuitePrefix(row) else {
                throw TestFailure(message: "Coverage row has no backticked suite label: \(row)",
                                  file: #file, line: #line)
            }
            guard let n = rowCount(row) else {
                throw TestFailure(message: "Coverage row has no parseable count: \(row)",
                                  file: #file, line: #line)
            }
            coverage[prefix, default: 0] += n
        }

        let liveKeys = Set(live.keys), covKeys = Set(coverage.keys)
        let missingRows = liveKeys.subtracting(covKeys).sorted()
        try expect(missingRows.isEmpty,
                   "Suite(s) registered but absent from the README coverage table: \(missingRows.joined(separator: ", "))")
        let staleRows = covKeys.subtracting(liveKeys).sorted()
        try expect(staleRows.isEmpty,
                   "README coverage table lists suite(s) not in the registry (renamed or removed?): \(staleRows.joined(separator: ", "))")
        for key in liveKeys.sorted() {
            try expectEqual(coverage[key] ?? -1, live[key] ?? -2,
                            "Coverage rows for `\(key)` sum to \(coverage[key] ?? -1) but the registry has \(live[key] ?? -2) `\(key)/…` tests")
        }
    }

    // ----- 6. Every relative link in the canonical navigational docs resolves -----

    // README is guarded by ReadmePolish/readmeRelativeLinksResolve; this
    // extends the identical check to the OTHER canonical navigational docs,
    // where a dead relative link (the class that shipped a 404 `bug_report.md`
    // link on the front page) would otherwise ship green. CHANGELOG is
    // deliberately excluded: it is an append-only record whose link-like
    // fragments (e.g. `[link](url)` describing the RTF renderer) are
    // illustrative prose, not navigation.
    static func everyCanonicalDocRelativeLinkResolves() throws {
        let docs = [
            "SECURITY.md",
            "CONTRIBUTING.md",
            ".github/PULL_REQUEST_TEMPLATE.md",
            "docs/RELEASING.md",
            "docs/IMPROVEMENT-ROADMAP.md",
        ]
        var missing: [String] = []
        var checked = 0
        let pattern = #"\]\(([^)]+)\)"#
        for rel in docs {
            let docURL = packageRoot.appendingPathComponent(rel)
            guard FileManager.default.fileExists(atPath: docURL.path) else {
                throw TestFailure(message: "Canonical doc \(rel) is missing (renamed? update this guard's list)",
                                  file: #file, line: #line)
            }
            let text = try String(contentsOf: docURL, encoding: .utf8)
            let baseDir = docURL.deletingLastPathComponent()
            var search = text.startIndex..<text.endIndex
            while let r = text.range(of: pattern, options: .regularExpression, range: search) {
                search = r.upperBound..<text.endIndex
                if isInsideInlineCode(r.lowerBound, in: text) { continue }
                var target = String(String(text[r]).dropFirst(2).dropLast())   // strip `](` and `)`
                if target.hasPrefix("http") || target.hasPrefix("mailto:") { continue }
                if let hash = target.firstIndex(of: "#") { target = String(target[..<hash]) }
                target = target.trimmingCharacters(in: .whitespaces)
                if target.isEmpty { continue }                                 // pure #anchor
                checked += 1
                let tgtURL = baseDir.appendingPathComponent(target)
                if !FileManager.default.fileExists(atPath: tgtURL.path) {
                    missing.append("\(rel) -> \(target)")
                }
            }
        }
        try expect(checked > 0,
                   "Guard parsed zero relative links across the canonical docs; the extractor or the doc set changed")
        try expect(missing.isEmpty,
                   "Canonical doc(s) link to file(s) that don't exist on disk: \(missing.joined(separator: "; "))")
    }

    // ----- 7. Files-tree "N tests across M suites" == live counts -----

    // The Files-tree line "N tests across M suites" states two counts no other
    // guard pins: it uses the bare word "tests" (so statedUnitTestCounts, which
    // matches "N unit tests", skips it) and it is the ONLY place the suite
    // count is written down. Pin N to the live case count and M to the live
    // distinct-suite count so neither can rot (this line lagged at 323/27 the
    // instant a suite or a test was added elsewhere).
    static func filesTreeTestAndSuiteCountsMatchRegistry() throws {
        let readme = try read("README.md")
        let registry = TestRegistry.cases.count
        let suites = Set(TestRegistry.cases.map { suitePrefix(of: $0.name) }).count
        let pattern = #"[0-9]+ tests across [0-9]+ suites"#
        guard let r = readme.range(of: pattern, options: .regularExpression) else {
            throw TestFailure(message: "README has no \"N tests across M suites\" line to pin",
                              file: #file, line: #line)
        }
        let ints = allMatchedInts(#"[0-9]+"#, in: String(readme[r]))
        try expectEqual(ints.count, 2, "Could not parse both counts from: \(readme[r])")
        try expectEqual(ints[0], registry,
                        "README Files tree says \(ints[0]) tests but the harness registered \(registry)")
        try expectEqual(ints[1], suites,
                        "README Files tree says \(ints[1]) suites but the registry has \(suites) distinct suites")
    }
}
