import Foundation

// Verifies the contribution infrastructure: CONTRIBUTING.md with the
// Contributor License Agreement (CLA), the GitHub PR template that
// references the CLA, and the issue template.
//
// Background: Multipaste 2.0.0+ is licensed under PolyForm Strict 1.0.0,
// which forbids derivative works and redistribution. Without a CLA, the
// act of opening a PR would technically violate the license. The CLA
// grants the licensor (a) the right to use, modify, distribute, and
// relicense the contribution, and (b) a one-time scoped permission for
// the contributor to make the proposed changes. These tests lock the
// contribution infrastructure in so it can't silently disappear.

enum ContributionTests {

    static func registerAll() {
        TestRegistry.register("Contribution/contributingFileExists", contributingFileExists)
        TestRegistry.register("Contribution/contributingHasCLALicenseGrant", contributingHasCLALicenseGrant)
        TestRegistry.register("Contribution/contributingPermitsFutureRelicensing", contributingPermitsFutureRelicensing)
        TestRegistry.register("Contribution/contributingExplainsPolyFormStrictContext", contributingExplainsPolyFormStrictContext)
        TestRegistry.register("Contribution/prTemplateExistsAndReferencesCLA", prTemplateExistsAndReferencesCLA)
        TestRegistry.register("Contribution/issueTemplateExists", issueTemplateExists)
    }

    // Package root is two directories above this test file.
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
            throw TestFailure(
                message: "Failed to read \(relativePath) at \(url.path): \(error)",
                file: file, line: line
            )
        }
    }

    static func contributingFileExists() throws {
        let url = packageRoot.appendingPathComponent("CONTRIBUTING.md")
        try expect(FileManager.default.fileExists(atPath: url.path),
                   "CONTRIBUTING.md not found at \(url.path)")
    }

    // The CLA must include a perpetual, irrevocable, royalty-free copyright
    // license. Without these magic words, the agreement is ambiguous and
    // contributors' grants may be limited or revocable.
    static func contributingHasCLALicenseGrant() throws {
        let text = try read("CONTRIBUTING.md")
        try expect(text.contains("Contributor License Agreement"),
                   "CONTRIBUTING.md missing the \"Contributor License Agreement\" heading")
        try expect(text.contains("perpetual"),
                   "CONTRIBUTING.md missing \"perpetual\" — license grant must be perpetual")
        try expect(text.contains("irrevocable"),
                   "CONTRIBUTING.md missing \"irrevocable\" — license grant must be irrevocable")
        try expect(text.contains("royalty-free"),
                   "CONTRIBUTING.md missing \"royalty-free\" — license grant must be royalty-free")
        try expect(text.contains("worldwide"),
                   "CONTRIBUTING.md missing \"worldwide\" — license grant must be worldwide")
    }

    // The critical clause: the licensor's right to relicense the
    // contribution under any future terms, including fully proprietary
    // closed-source. Without this, every accepted PR locks the project
    // out of relicensing without the contributor's explicit permission.
    static func contributingPermitsFutureRelicensing() throws {
        let text = try read("CONTRIBUTING.md")
        try expect(text.contains("relicense"),
                   "CONTRIBUTING.md missing the relicensing-right clause")
        // The clause must explicitly cover proprietary closed-source so
        // contributors cannot later claim they didn't expect this scope.
        try expect(text.contains("proprietary") && text.contains("closed-source"),
                   "CONTRIBUTING.md must explicitly mention proprietary closed-source relicensing")
    }

    // The CLA exists because PolyForm Strict forbids derivative works.
    // CONTRIBUTING.md should explain this so contributors understand
    // why the CLA is necessary, not just feel ambushed by it.
    static func contributingExplainsPolyFormStrictContext() throws {
        let text = try read("CONTRIBUTING.md")
        try expect(text.contains("PolyForm Strict"),
                   "CONTRIBUTING.md missing PolyForm Strict context")
        try expect(text.contains("source-available"),
                   "CONTRIBUTING.md should describe Multipaste as source-available")
    }

    static func prTemplateExistsAndReferencesCLA() throws {
        let url = packageRoot.appendingPathComponent(".github/PULL_REQUEST_TEMPLATE.md")
        try expect(FileManager.default.fileExists(atPath: url.path),
                   ".github/PULL_REQUEST_TEMPLATE.md not found at \(url.path)")
        let text = try read(".github/PULL_REQUEST_TEMPLATE.md")
        try expect(text.contains("CONTRIBUTING.md"),
                   "PR template should link to CONTRIBUTING.md")
        try expect(text.contains("CLA") || text.contains("Contributor License Agreement"),
                   "PR template should reference the CLA")
        // Must include a checkbox confirming the CLA — opening a PR
        // without reading the agreement is a footgun for everyone.
        try expect(text.contains("- [ ]"),
                   "PR template should include checkboxes for CLA confirmation")
        try expect(text.contains("relicense"),
                   "PR template should call out the relicensing clause specifically (it's the unusual one)")
    }

    static func issueTemplateExists() throws {
        let url = packageRoot.appendingPathComponent(".github/ISSUE_TEMPLATE/bug_report.md")
        try expect(FileManager.default.fileExists(atPath: url.path),
                   ".github/ISSUE_TEMPLATE/bug_report.md not found at \(url.path)")
        let text = try read(".github/ISSUE_TEMPLATE/bug_report.md")
        // Front-matter required for GitHub to recognize it as a template.
        try expect(text.hasPrefix("---\n"),
                   "Bug report template must start with YAML front-matter")
        try expect(text.contains("name: Bug report"),
                   "Bug report template missing \"name: Bug report\" front-matter field")
        // Useful prompts that make bug reports actionable.
        try expect(text.contains("macOS version"),
                   "Bug report template should ask for macOS version")
        try expect(text.contains("Multipaste version"),
                   "Bug report template should ask for Multipaste version")
    }
}
