// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

// Verifies that the LICENSE.md file at the package root is the PolyForm
// Strict 1.0.0 license — the most restrictive license in the PolyForm
// family — with the project's copyright header preserved on top, and that
// no stale MIT or AGPL text has slipped back in.
//
// Background: Multipaste 2.0.0 relicensed from MIT (1.0.0–1.9.0) directly
// to PolyForm Strict. PolyForm Strict is source-available, NOT OSI open
// source: noncommercial use is permitted, redistribution and derivative
// works are not. The license-decision discussion lives in CHANGELOG.md.
//
// The file is named `LICENSE.md` (not bare `LICENSE`) because the
// canonical PolyForm text is markdown — headings, links, emphasis — and
// only the `.md` extension lets GitHub and other viewers render it as
// formatted text instead of raw `#`/`##`/`**` syntax. PolyForm's own
// guidance is to use `LICENSE.md`. The `fileNameHasMarkdownExtension`
// test below locks this in.
//
// These tests run via the same harness as the rest of the suite
// (`swift run -c debug MultipasteTests`). If you intentionally change the
// license again, update the sentinels below.

enum LicenseTests {

    static func registerAll() {
        TestRegistry.register("License/fileExistsAtPackageRoot", fileExistsAtPackageRoot)
        TestRegistry.register("License/fileNameHasMarkdownExtension", fileNameHasMarkdownExtension)
        TestRegistry.register("License/isPolyFormStrict_1_0_0", isPolyFormStrict_1_0_0)
        TestRegistry.register("License/hasProjectCopyrightHeaderWithCommercialContact", hasProjectCopyrightHeaderWithCommercialContact)
        TestRegistry.register("License/forbidsDistributionAndDerivatives", forbidsDistributionAndDerivatives)
        TestRegistry.register("License/permitsNoncommercialUseExplicitly", permitsNoncommercialUseExplicitly)
        TestRegistry.register("License/hasPatentDefenseClause", hasPatentDefenseClause)
        TestRegistry.register("License/has32DayViolationCurePeriod", has32DayViolationCurePeriod)
        TestRegistry.register("License/hasNoLiabilityWarrantyDisclaimer", hasNoLiabilityWarrantyDisclaimer)
        TestRegistry.register("License/isStrictNotPolyFormNoncommercial", isStrictNotPolyFormNoncommercial)
        TestRegistry.register("License/hasNoStaleMITorAGPLText", hasNoStaleMITorAGPLText)
        TestRegistry.register("License/lineCountInExpectedRange", lineCountInExpectedRange)
        TestRegistry.register("License/hasContributionPointer", hasContributionPointer)
    }

    // The package root is two directories above this test file:
    //   Tests/MultipasteCoreTests/LicenseTests.swift → packageRoot/LICENSE.md
    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/Tests/MultipasteCoreTests
            .deletingLastPathComponent()   // …/Tests
            .deletingLastPathComponent()   // …/<packageRoot>
    }

    private static var licenseURL: URL {
        packageRoot.appendingPathComponent("LICENSE.md")
    }

    private static func readLicense(file: StaticString = #file, line: UInt = #line) throws -> String {
        do {
            return try String(contentsOf: licenseURL, encoding: .utf8)
        } catch {
            throw TestFailure(
                message: "Failed to read LICENSE.md at \(licenseURL.path): \(error)",
                file: file, line: line
            )
        }
    }

    static func fileExistsAtPackageRoot() throws {
        try expect(FileManager.default.fileExists(atPath: licenseURL.path),
                   "LICENSE.md not found at \(licenseURL.path)")
    }

    // PolyForm Strict canonical text uses markdown — headings (#, ##),
    // autolinks (<https://…>), emphasis (**, ***). Without the .md
    // extension, GitHub and most viewers render this raw, with `#` and
    // `**` literally visible. This test prevents a bare `LICENSE` from
    // sneaking back in.
    static func fileNameHasMarkdownExtension() throws {
        try expectEqual(licenseURL.lastPathComponent, "LICENSE.md",
                        "License file should be named LICENSE.md (markdown extension required for PolyForm canonical text to render)")
        try expectEqual(licenseURL.pathExtension, "md",
                        "License file extension should be 'md'")
        // Also guard against a stray bare-LICENSE file accidentally shipped
        // alongside LICENSE.md — would split the source of truth.
        let bare = packageRoot.appendingPathComponent("LICENSE")
        try expect(!FileManager.default.fileExists(atPath: bare.path),
                   "Both LICENSE and LICENSE.md exist at package root — split source of truth")
    }

    static func isPolyFormStrict_1_0_0() throws {
        let text = try readLicense()
        try expect(text.contains("PolyForm Strict License 1.0.0"),
                   "LICENSE.md missing PolyForm Strict 1.0.0 title")
        try expect(text.contains("polyformproject.org/licenses/strict/1.0.0"),
                   "LICENSE.md missing canonical PolyForm Strict URL")
    }

    static func hasProjectCopyrightHeaderWithCommercialContact() throws {
        let text = try readLicense()
        try expect(text.contains("Copyright (c) 2026 Rohin Agrawal"),
                   "LICENSE.md missing project copyright line")
        try expect(text.contains("Multipaste"),
                   "LICENSE.md header missing project name")
        try expect(text.contains("rohin.agrawal@gmail.com"),
                   "LICENSE.md header missing commercial-licensing contact email")
    }

    // The Strict-defining clause. PolyForm Noncommercial omits this last
    // half; PolyForm Strict is the variant that bans distribution AND
    // derivative works in addition to commercial use.
    static func forbidsDistributionAndDerivatives() throws {
        let text = try readLicense()
        try expect(text.contains("other than distributing the software or making changes or new works based on the software"),
                   "LICENSE.md missing Strict-defining \"no distribution / no derivatives\" clause")
    }

    static func permitsNoncommercialUseExplicitly() throws {
        let text = try readLicense()
        try expect(text.contains("## Noncommercial Purposes"),
                   "LICENSE.md missing \"Noncommercial Purposes\" section header")
        try expect(text.contains("Any noncommercial purpose is a permitted purpose."),
                   "LICENSE.md missing \"Noncommercial Purposes\" clause body")
        try expect(text.contains("## Personal Uses"),
                   "LICENSE.md missing \"Personal Uses\" section")
        try expect(text.contains("## Noncommercial Organizations"),
                   "LICENSE.md missing \"Noncommercial Organizations\" section")
    }

    static func hasPatentDefenseClause() throws {
        let text = try readLicense()
        try expect(text.contains("## Patent Defense"),
                   "LICENSE.md missing \"Patent Defense\" section header")
        try expect(text.contains("your patent license for the software granted under these terms ends immediately"),
                   "LICENSE.md missing Patent Defense termination clause")
    }

    static func has32DayViolationCurePeriod() throws {
        let text = try readLicense()
        try expect(text.contains("## Violations"),
                   "LICENSE.md missing \"Violations\" section header")
        try expect(text.contains("within 32 days of receiving notice"),
                   "LICENSE.md missing 32-day cure period for violations")
    }

    static func hasNoLiabilityWarrantyDisclaimer() throws {
        let text = try readLicense()
        try expect(text.contains("## No Liability"),
                   "LICENSE.md missing \"No Liability\" section header")
        try expect(text.contains("the software comes as is"),
                   "LICENSE.md missing \"comes as is\" warranty disclaimer")
        try expect(text.contains("without any warranty or condition"),
                   "LICENSE.md missing warranty disclaimer body")
    }

    // Guard against accidentally landing on the wrong PolyForm variant.
    // PolyForm Noncommercial allows derivative works — if we want maximum
    // restrictiveness, that's the wrong choice. This test will fail loudly
    // if someone swaps "Strict" for "Noncommercial" in the LICENSE.md.
    static func isStrictNotPolyFormNoncommercial() throws {
        let text = try readLicense()
        try expect(!text.contains("PolyForm Noncommercial License"),
                   "LICENSE.md has switched to PolyForm Noncommercial — wrong variant; project uses Strict")
        try expect(!text.contains("polyformproject.org/licenses/noncommercial/"),
                   "LICENSE.md references PolyForm Noncommercial URL — wrong variant")
    }

    // Guards against partial overwrites or botched merges that leave behind
    // the previous license texts. MIT was used 1.0.0–1.9.0; AGPL was
    // considered briefly during the 2.0.0 relicense discussion.
    static func hasNoStaleMITorAGPLText() throws {
        let text = try readLicense()
        try expect(!text.contains("Permission is hereby granted, free of charge"),
                   "LICENSE.md still contains MIT permission grant")
        try expect(!text.contains("MIT License"),
                   "LICENSE.md still references MIT License")
        try expect(!text.contains("GNU Affero General Public License"),
                   "LICENSE.md still references AGPL")
        try expect(!text.contains("GNU AFFERO GENERAL PUBLIC LICENSE"),
                   "LICENSE.md still contains AGPL title")
        try expect(!text.contains("GNU General Public License"),
                   "LICENSE.md still references GPL")
    }

    // Project header (~20 lines including contribution-pointer block) +
    // separator (1) + PolyForm Strict canonical (59 lines) ≈ 81 lines
    // (give or take final newline). Allow 75–90 to catch wholesale
    // truncation or duplication without being so tight that header
    // tweaks break the test.
    static func lineCountInExpectedRange() throws {
        let text = try readLicense()
        let count = text.components(separatedBy: "\n").count
        try expect(count >= 75 && count <= 90,
                   "LICENSE.md line count \(count) outside expected 75–90 range")
    }

    // The project copyright header points contributors at CONTRIBUTING.md
    // so they discover the CLA without having to find it themselves.
    // PolyForm Strict otherwise forbids derivative works; the CLA is what
    // makes contributions legal at all.
    static func hasContributionPointer() throws {
        let text = try readLicense()
        try expect(text.contains("CONTRIBUTING.md"),
                   "LICENSE.md header missing pointer to CONTRIBUTING.md")
        try expect(text.contains("Contributor License Agreement"),
                   "LICENSE.md header missing reference to the Contributor License Agreement")
    }
}
