// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

// Asserts version-string consistency across every artifact a user can
// see. The bug this suite prevents shipped once: in 2.0.0, the README's
// Easy-install section still said "Download Multipaste-1.9.0.dmg" after
// the version had been bumped to 2.0.0 in Version.swift and Info.plist.
// That broke the download link.
//
// All artifacts that mention the Multipaste version must agree with the
// canonical source (Sources/MultipasteCore/Version.swift). The canonical
// source is what `MultipasteVersion.value` resolves to at runtime — what
// the running app reports as its own version.
//
// Out of scope (intentionally):
//   - Historical version references in CHANGELOG sub-sections (the
//     v1.9.0 entry SHOULD say 1.9.0).
//   - "Fixed in v1.6.0"-style historical bug references in the README's
//     "bugs we fixed" section.
//   - PolyForm Strict 1.0.0 — that's the LICENSE version, not the app
//     version, and is locked down separately by LicenseTests.
//   - The Homebrew tap (lives in a separate repo).
//   - Approximate size strings ("~460 KB DMG") — these would tightly
//     couple tests to build output and would break on every release.

enum VersionConsistencyTests {

    static func registerAll() {
        TestRegistry.register("VersionConsistency/swiftAndPlistAgreeOnVersion", swiftAndPlistAgreeOnVersion)
        TestRegistry.register("VersionConsistency/readmeHeroDownloadCTAMatchesVersion", readmeHeroDownloadCTAMatchesVersion)
        TestRegistry.register("VersionConsistency/readmeInstallSectionReferencesCurrentDMG", readmeInstallSectionReferencesCurrentDMG)
        TestRegistry.register("VersionConsistency/readmeContainsNoStaleDMGReferences", readmeContainsNoStaleDMGReferences)
        TestRegistry.register("VersionConsistency/changelogLatestEntryMatchesVersion", changelogLatestEntryMatchesVersion)
        TestRegistry.register("VersionConsistency/securityPolicySupportsCurrentMajorSeries", securityPolicySupportsCurrentMajorSeries)
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

    // The canonical version, read FROM the source of truth.
    // Pattern: `public static let value = "X.Y.Z"`
    private static func canonicalVersion(file: StaticString = #file, line: UInt = #line) throws -> String {
        let source = try read("Sources/MultipasteCore/Version.swift")
        guard let range = source.range(of: #"static let value = "([0-9]+\.[0-9]+\.[0-9]+)""#,
                                        options: .regularExpression) else {
            throw TestFailure(
                message: "Could not parse `static let value = \"X.Y.Z\"` from Version.swift",
                file: file, line: line)
        }
        // Extract just the X.Y.Z capture.
        let match = String(source[range])
        guard let inner = match.range(of: #"[0-9]+\.[0-9]+\.[0-9]+"#,
                                      options: .regularExpression) else {
            throw TestFailure(
                message: "Could not extract X.Y.Z from \(match)",
                file: file, line: line)
        }
        return String(match[inner])
    }

    // ----- 1. Version.swift ⇔ Info.plist -----

    static func swiftAndPlistAgreeOnVersion() throws {
        let version = try canonicalVersion()
        let plist = try read("Resources/Info.plist")
        // The CFBundleShortVersionString value follows on a line of its own
        // wrapped in <string>...</string>.
        let needle = "<key>CFBundleShortVersionString</key>"
        guard let keyRange = plist.range(of: needle) else {
            throw TestFailure(message: "Info.plist missing CFBundleShortVersionString key",
                              file: #file, line: #line)
        }
        let after = String(plist[keyRange.upperBound...])
        guard let stringRange = after.range(of: #"<string>([0-9]+\.[0-9]+\.[0-9]+)</string>"#,
                                            options: .regularExpression) else {
            throw TestFailure(message: "Info.plist CFBundleShortVersionString value not parseable",
                              file: #file, line: #line)
        }
        let stringTag = String(after[stringRange])
        let plistVersion = stringTag
            .replacingOccurrences(of: "<string>", with: "")
            .replacingOccurrences(of: "</string>", with: "")
        try expectEqual(plistVersion, version,
                        "Info.plist CFBundleShortVersionString (\(plistVersion)) doesn't match Version.swift (\(version))")
    }

    // ----- 2. README hero "Download vX.Y.Z" -----

    static func readmeHeroDownloadCTAMatchesVersion() throws {
        let version = try canonicalVersion()
        let readme = try read("README.md")
        // The hero CTA reads "↓ Download vX.Y.Z (... DMG)".
        try expect(readme.contains("Download v\(version)"),
                   "README hero Download CTA must reference v\(version) (the canonical version from Version.swift)")
    }

    // ----- 3. README install section "Multipaste-X.Y.Z.dmg" -----

    static func readmeInstallSectionReferencesCurrentDMG() throws {
        let version = try canonicalVersion()
        let readme = try read("README.md")
        let expectedFilename = "Multipaste-\(version).dmg"
        try expect(readme.contains(expectedFilename),
                   "README must reference the current DMG filename `\(expectedFilename)` somewhere in the install section")
    }

    // ----- 4. Regression: no stale Multipaste-X.Y.Z.dmg references -----

    // The bug that motivated this entire suite: README said
    // "Multipaste-1.9.0.dmg" after Version.swift was bumped to 2.0.0,
    // breaking the download link. This test fails if any
    // "Multipaste-X.Y.Z.dmg" pattern in README does NOT match the
    // canonical version.
    static func readmeContainsNoStaleDMGReferences() throws {
        let version = try canonicalVersion()
        let readme = try read("README.md")

        // Find every Multipaste-X.Y.Z.dmg occurrence.
        let pattern = #"Multipaste-[0-9]+\.[0-9]+\.[0-9]+\.dmg"#
        var stale: [String] = []
        var search = readme.startIndex..<readme.endIndex
        while let r = readme.range(of: pattern, options: .regularExpression, range: search) {
            let found = String(readme[r])
            if found != "Multipaste-\(version).dmg" {
                stale.append(found)
            }
            search = r.upperBound..<readme.endIndex
        }
        try expect(stale.isEmpty,
                   "README references stale DMG filenames: \(stale.joined(separator: ", ")). Current version is \(version); update or remove these references.")
    }

    // ----- 5. CHANGELOG's latest ## entry matches -----

    static func changelogLatestEntryMatchesVersion() throws {
        let version = try canonicalVersion()
        let changelog = try read("CHANGELOG.md")
        // The first `## X.Y.Z` heading should match the canonical version.
        // We scan from the top to find the first `## ` line.
        for line in changelog.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                // Expected form: `## 2.0.0 — 2026-05-16`
                let body = String(line.dropFirst(3))
                if let firstVersion = body.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+"#,
                                                 options: .regularExpression) {
                    let found = String(body[firstVersion])
                    try expectEqual(found, version,
                                    "CHANGELOG's latest entry is for \(found) but Version.swift says \(version) — relicense / version-bump in progress?")
                    return
                }
            }
        }
        throw TestFailure(
            message: "CHANGELOG.md has no `## X.Y.Z` entry heading",
            file: #file, line: #line)
    }

    // ----- 6. SECURITY.md supported-versions table includes current major -----

    static func securityPolicySupportsCurrentMajorSeries() throws {
        let version = try canonicalVersion()
        let major = String(version.split(separator: ".").prefix(2).joined(separator: "."))
        let security = try read("SECURITY.md")
        // The supported-versions table should mention the current major
        // series (e.g., "2.0.x") as supported.
        try expect(security.contains("\(major).x"),
                   "SECURITY.md supported-versions table should mention \(major).x as supported (current major series)")
    }
}
