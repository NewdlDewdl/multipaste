import Foundation

// Verifies that the LICENSE file at the package root is the PolyForm Strict
// 1.0.0 license — the most restrictive license in the PolyForm family —
// with the project's copyright header preserved on top, and that no stale
// MIT or AGPL text has slipped back in.
//
// Background: Multipaste 2.0.0 relicensed from MIT (1.0.0–1.9.0) directly
// to PolyForm Strict. PolyForm Strict is source-available, NOT OSI open
// source: noncommercial use is permitted, redistribution and derivative
// works are not. The license-decision discussion lives in CHANGELOG.md.
//
// These tests run via the same harness as the rest of the suite
// (`swift run -c debug MultipasteTests`). If you intentionally change the
// license again, update the sentinels below.

enum LicenseTests {

    static func registerAll() {
        TestRegistry.register("License/fileExistsAtPackageRoot", fileExistsAtPackageRoot)
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
    }

    // The package root is two directories above this test file:
    //   Tests/MultipasteCoreTests/LicenseTests.swift → packageRoot/LICENSE
    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/Tests/MultipasteCoreTests
            .deletingLastPathComponent()   // …/Tests
            .deletingLastPathComponent()   // …/<packageRoot>
    }

    private static var licenseURL: URL {
        packageRoot.appendingPathComponent("LICENSE")
    }

    private static func readLicense(file: StaticString = #file, line: UInt = #line) throws -> String {
        do {
            return try String(contentsOf: licenseURL, encoding: .utf8)
        } catch {
            throw TestFailure(
                message: "Failed to read LICENSE at \(licenseURL.path): \(error)",
                file: file, line: line
            )
        }
    }

    static func fileExistsAtPackageRoot() throws {
        try expect(FileManager.default.fileExists(atPath: licenseURL.path),
                   "LICENSE not found at \(licenseURL.path)")
    }

    static func isPolyFormStrict_1_0_0() throws {
        let text = try readLicense()
        try expect(text.contains("PolyForm Strict License 1.0.0"),
                   "LICENSE missing PolyForm Strict 1.0.0 title")
        try expect(text.contains("polyformproject.org/licenses/strict/1.0.0"),
                   "LICENSE missing canonical PolyForm Strict URL")
    }

    static func hasProjectCopyrightHeaderWithCommercialContact() throws {
        let text = try readLicense()
        try expect(text.contains("Copyright (c) 2026 Rohin Agrawal"),
                   "LICENSE missing project copyright line")
        try expect(text.contains("Multipaste"),
                   "LICENSE header missing project name")
        try expect(text.contains("rohin.agrawal@gmail.com"),
                   "LICENSE header missing commercial-licensing contact email")
    }

    // The Strict-defining clause. PolyForm Noncommercial omits this last
    // half; PolyForm Strict is the variant that bans distribution AND
    // derivative works in addition to commercial use.
    static func forbidsDistributionAndDerivatives() throws {
        let text = try readLicense()
        try expect(text.contains("other than distributing the software or making changes or new works based on the software"),
                   "LICENSE missing Strict-defining \"no distribution / no derivatives\" clause")
    }

    static func permitsNoncommercialUseExplicitly() throws {
        let text = try readLicense()
        try expect(text.contains("## Noncommercial Purposes"),
                   "LICENSE missing \"Noncommercial Purposes\" section header")
        try expect(text.contains("Any noncommercial purpose is a permitted purpose."),
                   "LICENSE missing \"Noncommercial Purposes\" clause body")
        try expect(text.contains("## Personal Uses"),
                   "LICENSE missing \"Personal Uses\" section")
        try expect(text.contains("## Noncommercial Organizations"),
                   "LICENSE missing \"Noncommercial Organizations\" section")
    }

    static func hasPatentDefenseClause() throws {
        let text = try readLicense()
        try expect(text.contains("## Patent Defense"),
                   "LICENSE missing \"Patent Defense\" section header")
        try expect(text.contains("your patent license for the software granted under these terms ends immediately"),
                   "LICENSE missing Patent Defense termination clause")
    }

    static func has32DayViolationCurePeriod() throws {
        let text = try readLicense()
        try expect(text.contains("## Violations"),
                   "LICENSE missing \"Violations\" section header")
        try expect(text.contains("within 32 days of receiving notice"),
                   "LICENSE missing 32-day cure period for violations")
    }

    static func hasNoLiabilityWarrantyDisclaimer() throws {
        let text = try readLicense()
        try expect(text.contains("## No Liability"),
                   "LICENSE missing \"No Liability\" section header")
        try expect(text.contains("the software comes as is"),
                   "LICENSE missing \"comes as is\" warranty disclaimer")
        try expect(text.contains("without any warranty or condition"),
                   "LICENSE missing warranty disclaimer body")
    }

    // Guard against accidentally landing on the wrong PolyForm variant.
    // PolyForm Noncommercial allows derivative works — if we want maximum
    // restrictiveness, that's the wrong choice. This test will fail loudly
    // if someone swaps "Strict" for "Noncommercial" in the LICENSE.
    static func isStrictNotPolyFormNoncommercial() throws {
        let text = try readLicense()
        try expect(!text.contains("PolyForm Noncommercial License"),
                   "LICENSE has switched to PolyForm Noncommercial — wrong variant; project uses Strict")
        try expect(!text.contains("polyformproject.org/licenses/noncommercial/"),
                   "LICENSE references PolyForm Noncommercial URL — wrong variant")
    }

    // Guards against partial overwrites or botched merges that leave behind
    // the previous license texts. MIT was used 1.0.0–1.9.0; AGPL was
    // considered briefly during the 2.0.0 relicense discussion.
    static func hasNoStaleMITorAGPLText() throws {
        let text = try readLicense()
        try expect(!text.contains("Permission is hereby granted, free of charge"),
                   "LICENSE still contains MIT permission grant")
        try expect(!text.contains("MIT License"),
                   "LICENSE still references MIT License")
        try expect(!text.contains("GNU Affero General Public License"),
                   "LICENSE still references AGPL")
        try expect(!text.contains("GNU AFFERO GENERAL PUBLIC LICENSE"),
                   "LICENSE still contains AGPL title")
        try expect(!text.contains("GNU General Public License"),
                   "LICENSE still references GPL")
    }

    // Project header (14 lines) + blank (1) + separator (1) + blank (1) +
    // PolyForm Strict canonical (59 lines) ≈ 76 lines (give or take final
    // newline). Allow 70–80 to catch wholesale truncation or duplication
    // without being so tight that minor whitespace tweaks break the test.
    static func lineCountInExpectedRange() throws {
        let text = try readLicense()
        let count = text.components(separatedBy: "\n").count
        try expect(count >= 70 && count <= 80,
                   "LICENSE line count \(count) outside expected 70–80 range")
    }
}
