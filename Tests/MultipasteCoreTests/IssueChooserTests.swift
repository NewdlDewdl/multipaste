// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

// Verifies GitHub's issue-template chooser is fully configured per
// https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository
//
// Covers:
//   - .github/ISSUE_TEMPLATE/bug_report.yml      (modern YAML issue form,
//                                                 required fields locked in)
//   - .github/ISSUE_TEMPLATE/feature_request.yml (with CLA acknowledgment
//                                                 for implementers)
//   - .github/ISSUE_TEMPLATE/config.yml          (chooser: blank issues
//                                                 disabled + contact links)
//   - SECURITY.md                                (responsible disclosure
//                                                 policy that the chooser
//                                                 routes security reports to)
//
// Why YAML forms over the old .md templates: structured fields with
// required validation, dropdowns, checkboxes. Users can't accidentally
// open an issue without the macOS version, install method, or CLA
// acknowledgment.

enum IssueChooserTests {

    static func registerAll() {
        TestRegistry.register("IssueChooser/bugReportYamlFormHasRequiredFields", bugReportYamlFormHasRequiredFields)
        TestRegistry.register("IssueChooser/featureRequestYamlFormHasCLAAcknowledgment", featureRequestYamlFormHasCLAAcknowledgment)
        TestRegistry.register("IssueChooser/chooserConfigDisablesBlankIssues", chooserConfigDisablesBlankIssues)
        TestRegistry.register("IssueChooser/chooserConfigHasRequiredContactLinks", chooserConfigHasRequiredContactLinks)
        TestRegistry.register("IssueChooser/oldMarkdownBugTemplateRemoved", oldMarkdownBugTemplateRemoved)
        TestRegistry.register("IssueChooser/securityPolicyExistsAtRepoRoot", securityPolicyExistsAtRepoRoot)
        TestRegistry.register("IssueChooser/securityPolicyDocumentsReportingChannel", securityPolicyDocumentsReportingChannel)
        TestRegistry.register("IssueChooser/securityPolicyDocumentsSupportedVersions", securityPolicyDocumentsSupportedVersions)
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
            throw TestFailure(
                message: "Failed to read \(relativePath) at \(url.path): \(error)",
                file: file, line: line
            )
        }
    }

    private static func fileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: packageRoot.appendingPathComponent(relativePath).path)
    }

    // ----- Bug report YAML form -----

    static func bugReportYamlFormHasRequiredFields() throws {
        let path = ".github/ISSUE_TEMPLATE/bug_report.yml"
        try expect(fileExists(path),
                   "\(path) not found — modern YAML issue form is required (old .md template was removed)")
        let text = try read(path)

        // GitHub YAML form schema fields.
        try expect(text.contains("name: Bug report"),
                   "bug_report.yml missing `name: Bug report`")
        try expect(text.contains("description:"),
                   "bug_report.yml missing top-level `description:`")
        try expect(text.contains("body:"),
                   "bug_report.yml missing `body:` array (YAML form schema requirement)")

        // Required content prompts. If any of these are absent the form
        // will be filed without info we need to triage.
        for required in [
            "macOS version",
            "Multipaste version",
            "Install method",
            "CPU architecture",
            "Steps to reproduce",
        ] {
            try expect(text.contains(required),
                       "bug_report.yml missing prompt for \"\(required)\"")
        }

        // Each required field should mark itself required via the schema.
        // We assert at least 5 `required: true` lines (matches the 5 fields
        // above + the pre-flight checkboxes).
        let requiredCount = text.components(separatedBy: "required: true").count - 1
        try expect(requiredCount >= 5,
                   "bug_report.yml should have at least 5 required:true fields, got \(requiredCount)")

        // Security reports must be routed AWAY from this form to email.
        try expect(text.contains("rohin.agrawal@gmail.com"),
                   "bug_report.yml should direct security reports to email instead of the public form")
    }

    // ----- Feature request YAML form -----

    static func featureRequestYamlFormHasCLAAcknowledgment() throws {
        let path = ".github/ISSUE_TEMPLATE/feature_request.yml"
        try expect(fileExists(path),
                   "\(path) not found — feature requests need their own template, not a generic issue")
        let text = try read(path)

        try expect(text.contains("name: Feature request"),
                   "feature_request.yml missing `name: Feature request`")
        try expect(text.contains("body:"),
                   "feature_request.yml missing `body:` array")

        // The CLA is the load-bearing clause for any PR; if someone opens
        // a feature request and offers to implement it, the form must
        // surface the CLA — especially the relicensing-right clause.
        try expect(text.contains("Contributor License Agreement"),
                   "feature_request.yml should reference the Contributor License Agreement for implementers")
        try expect(text.contains("relicense"),
                   "feature_request.yml should specifically mention the relicensing right (the unusual clause in the CLA)")
        try expect(text.contains("CONTRIBUTING.md"),
                   "feature_request.yml should link to CONTRIBUTING.md")

        // Importance dropdown helps prioritize without contributors having
        // to argue for their feature in prose.
        try expect(text.contains("importance") || text.contains("important"),
                   "feature_request.yml should ask about how important the feature is")
    }

    // ----- Chooser config -----

    static func chooserConfigDisablesBlankIssues() throws {
        let path = ".github/ISSUE_TEMPLATE/config.yml"
        try expect(fileExists(path),
                   "\(path) not found — chooser config is required to disable blank issues")
        let text = try read(path)
        try expect(text.contains("blank_issues_enabled: false"),
                   "config.yml must set `blank_issues_enabled: false` to force users into a template")
    }

    static func chooserConfigHasRequiredContactLinks() throws {
        let text = try read(".github/ISSUE_TEMPLATE/config.yml")
        try expect(text.contains("contact_links:"),
                   "config.yml missing `contact_links:` array")

        // Four off-ramps that should always be available BEFORE the bug
        // and feature templates: security email, commercial licensing
        // email, discussions, contributing doc.
        try expect(text.contains("Security"),
                   "config.yml missing security contact link")
        try expect(text.contains("Commercial"),
                   "config.yml missing commercial-licensing contact link")
        try expect(text.contains("Discussions") || text.contains("discussions"),
                   "config.yml missing Discussions contact link")
        try expect(text.contains("CONTRIBUTING.md"),
                   "config.yml missing CONTRIBUTING.md contact link")

        // The actual destinations must be present too.
        try expect(text.contains("rohin.agrawal@gmail.com"),
                   "config.yml security/commercial links missing email destination")
        try expect(text.contains("github.com/NewdlDewdl/multipaste/discussions"),
                   "config.yml Discussions link missing canonical URL")
    }

    // The old .md template was replaced by a YAML form. If a stray .md
    // sneaks back in, GitHub may show both in the chooser, which would be
    // confusing — guard against that.
    static func oldMarkdownBugTemplateRemoved() throws {
        try expect(!fileExists(".github/ISSUE_TEMPLATE/bug_report.md"),
                   "Old .github/ISSUE_TEMPLATE/bug_report.md still exists — should have been replaced by bug_report.yml")
    }

    // ----- SECURITY.md (linked from the chooser) -----

    static func securityPolicyExistsAtRepoRoot() throws {
        // GitHub looks for SECURITY.md at repo root, in /docs, or in /.github.
        // Multipaste keeps it at repo root for maximum discoverability.
        try expect(fileExists("SECURITY.md"),
                   "SECURITY.md not found at repo root — GitHub Security tab will not surface a policy")
    }

    static func securityPolicyDocumentsReportingChannel() throws {
        let text = try read("SECURITY.md")
        // Reporting channel must be unambiguous: an email, with subject
        // guidance, and explicit "don't open a public issue" wording.
        try expect(text.contains("rohin.agrawal@gmail.com"),
                   "SECURITY.md missing the security-report email")
        try expect(text.contains("Multipaste security"),
                   "SECURITY.md missing the subject-line convention")
        try expect(text.lowercased().contains("do not open a public") || text.lowercased().contains("do not file a public") || text.lowercased().contains("do not use this form") || text.lowercased().contains("do not open a public github issue"),
                   "SECURITY.md should explicitly tell reporters NOT to open a public issue")
    }

    static func securityPolicyDocumentsSupportedVersions() throws {
        let text = try read("SECURITY.md")
        try expect(text.contains("Supported versions") || text.contains("Supported Versions"),
                   "SECURITY.md missing \"Supported versions\" section")
        // The currently-supported series must be mentioned by version
        // prefix. Bump these markers when Multipaste does a major release.
        try expect(text.contains("2.0"),
                   "SECURITY.md should mention 2.0.x as a supported version")
    }
}
