// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

// Locks in README UX/design decisions so they can't silently regress on
// a future edit. Sister to LicensingMetadataTests (which guards the
// SPDX/REUSE compliance side of README structure) and to the existing
// `LicensingMetadata/readmeBadgeIsNotInIntroHeader` test (which keeps
// the intimidating PolyForm STRICT badge out of the intro).
//
// What's tested here:
//   1. The hero logo file exists at the expected path.
//   2. The hero block at the top of README references the logo with a
//      centered <p align="center"> wrapper, an explicit width, and
//      meaningful alt text.
//   3. There's a quick-nav row near the top with multiple anchor links
//      so users can jump to Install / Snippets / License / Contribute
//      without scrolling 700 lines.
//   4. A prominent Download call-to-action appears near the top —
//      sized to invite the click, not buried inside a paragraph.

enum ReadmePolishTests {

    static let logoRelativePath = "Resources/icon-256.png"

    static func registerAll() {
        TestRegistry.register("ReadmePolish/logoFileExistsAtExpectedPath", logoFileExistsAtExpectedPath)
        TestRegistry.register("ReadmePolish/readmeHasCenteredLogoHero", readmeHasCenteredLogoHero)
        TestRegistry.register("ReadmePolish/readmeHasQuickNavLinks", readmeHasQuickNavLinks)
        TestRegistry.register("ReadmePolish/readmeHasDownloadCallToAction", readmeHasDownloadCallToAction)
        TestRegistry.register("ReadmePolish/readmeDoesNotClaimBuiltInOneSession", readmeDoesNotClaimBuiltInOneSession)
        TestRegistry.register("ReadmePolish/snippetExampleUsesGenericEmail", snippetExampleUsesGenericEmail)
        TestRegistry.register("ReadmePolish/readmeRelativeLinksResolve", readmeRelativeLinksResolve)
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/Tests/MultipasteCoreTests
            .deletingLastPathComponent()   // …/Tests
            .deletingLastPathComponent()   // …/<packageRoot>
    }

    private static func readReadme() throws -> String {
        let url = packageRoot.appendingPathComponent("README.md")
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw TestFailure(message: "Failed to read README.md: \(error)",
                              file: #file, line: #line)
        }
    }

    private static func intro(of text: String, lines: Int = 30) -> String {
        text.components(separatedBy: "\n").prefix(lines).joined(separator: "\n")
    }

    // ----- Every relative markdown link resolves on disk -----

    // The dead-link class this guards: the README linked its bug-report
    // template to `.github/ISSUE_TEMPLATE/bug_report.md` after that file was
    // replaced by a YAML form, so the front-page link 404'd and no test
    // noticed. Extracts every `](target)` that isn't an http(s)/mailto URL
    // or a pure `#anchor` and asserts the file exists.
    static func readmeRelativeLinksResolve() throws {
        let readme = try readReadme()
        var missing: [String] = []
        var search = readme.startIndex..<readme.endIndex
        let pattern = #"\]\(([^)]+)\)"#
        while let r = readme.range(of: pattern, options: .regularExpression, range: search) {
            search = r.upperBound..<readme.endIndex
            // Skip a `](target)` fragment fully enclosed in inline-code
            // backticks: that's prose ABOUT link syntax (e.g. this guard's
            // own coverage-table row), not a rendered link.
            let before = r.lowerBound > readme.startIndex ? readme[readme.index(before: r.lowerBound)] : " "
            let after = r.upperBound < readme.endIndex ? readme[r.upperBound] : " "
            if before == "`" && after == "`" { continue }
            var target = String(String(readme[r]).dropFirst(2).dropLast())   // strip `](` and `)`
            if target.hasPrefix("http") || target.hasPrefix("mailto:") { continue }
            if let hash = target.firstIndex(of: "#") { target = String(target[..<hash]) }
            target = target.trimmingCharacters(in: .whitespaces)
            if target.isEmpty { continue }                                   // pure #anchor
            let url = packageRoot.appendingPathComponent(target)
            if !FileManager.default.fileExists(atPath: url.path) { missing.append(target) }
        }
        try expect(missing.isEmpty,
                   "README links to file(s) that don't exist on disk: \(missing.joined(separator: ", "))")
    }

    // ----- 1. Logo file exists -----

    static func logoFileExistsAtExpectedPath() throws {
        let url = packageRoot.appendingPathComponent(logoRelativePath)
        try expect(FileManager.default.fileExists(atPath: url.path),
                   "Hero logo \(logoRelativePath) not found — README's hero <img> will 404")

        // PNG signature: 89 50 4E 47 0D 0A 1A 0A
        let data = try Data(contentsOf: url)
        try expect(data.count > 100,
                   "Hero logo is suspiciously small (\(data.count) bytes) — corrupt or empty?")
        let pngSig: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let head = Array(data.prefix(8))
        try expectEqual(head, pngSig,
                        "Hero logo doesn't start with PNG magic bytes — wrong file type?")
    }

    // ----- 2. Hero block at top of README -----

    static func readmeHasCenteredLogoHero() throws {
        let head = intro(of: try readReadme())
        try expect(head.contains("<p align=\"center\">"),
                   "README intro missing `<p align=\"center\">` hero wrapper")
        try expect(head.contains(logoRelativePath),
                   "README intro missing reference to the hero logo at \(logoRelativePath)")
        try expect(head.contains("width=\"192\""),
                   "README hero logo missing explicit width — could render uncontrolled size")
        try expect(head.contains("alt=") && head.contains("Multipaste"),
                   "README hero logo missing meaningful alt text mentioning Multipaste (accessibility)")
        try expect(head.contains("<h1 align=\"center\">Multipaste</h1>"),
                   "README intro missing centered <h1>Multipaste</h1> below the hero logo")
    }

    // ----- 3. Quick-nav row -----

    static func readmeHasQuickNavLinks() throws {
        let head = intro(of: try readReadme())
        // A quick-nav row should help users jump to the most-clicked
        // sections without scrolling the 700-line doc. We require at
        // least 4 of these anchor targets in the intro.
        let expectedAnchors = ["#install", "#keys", "#snippet-expansion",
                               "#how-does-it-compare", "#privacy",
                               "#license", "#contributing"]
        let present = expectedAnchors.filter { head.contains($0) }
        try expect(present.count >= 4,
                   "README intro should have a quick-nav with ≥4 section anchors. Found: \(present.joined(separator: ", "))")
    }

    // ----- 4. Download CTA -----

    static func readmeHasDownloadCallToAction() throws {
        let head = intro(of: try readReadme())
        try expect(head.lowercased().contains("download"),
                   "README intro missing a \"Download\" call-to-action")
        try expect(head.contains("releases/latest"),
                   "README intro missing a link to the latest GitHub release (the actual download)")
        // Bold wrapping makes the CTA visually pop. Either <strong> or
        // markdown ** is fine.
        try expect(head.contains("<strong>") || head.contains("**"),
                   "README Download CTA isn't bold — won't read as a primary action")
    }

    // ----- 5. "Built in one session" — was true once, became false -----

    // The original v1.0–v1.5-ish work landed in a single session on
    // 2026-05-11 and the "Made for" footer reflected that. Since then
    // the project has been iterated on across many more sessions —
    // v1.5 → v1.9 feature work, then v2.0.0's relicense + SPDX/REUSE
    // standards compliance + CLA + issue-template chooser + SECURITY +
    // version-consistency tests + README hero — so the claim is now
    // factually wrong. This test catches that exact wording plus a few
    // common variants so the claim can't sneak back in.
    static func readmeDoesNotClaimBuiltInOneSession() throws {
        let text = try readReadme()
        let staleClaims = [
            "in one session",
            "in a single session",
            "in one sitting",
            "in a single sitting",
        ]
        let hit = staleClaims.first(where: { text.lowercased().contains($0) })
        try expect(hit == nil,
                   "README contains a stale claim about being built quickly: \"\(hit ?? "")\". The project has been worked on across many sessions; rewrite the \"Made for\" footer to drop the timing claim.")
    }

    // ----- 6. Snippet example uses a generic email, not a personal one -----

    // The snippet-expansion section walks through "copy an email, set
    // a trigger for it, expand it elsewhere." Using a generic
    // placeholder (you@example.com) instead of the maintainer's actual
    // address makes the example feel about the reader, not about the
    // author. Also avoids the appearance of leaking a personal email
    // into a tutorial section even though the address is also
    // intentionally visible in the License / SECURITY / Commercial
    // sections.
    static func snippetExampleUsesGenericEmail() throws {
        let text = try readReadme()
        guard let start = text.range(of: "## Snippet expansion") else {
            throw TestFailure(message: "README missing \"## Snippet expansion\" section header",
                              file: #file, line: #line)
        }
        let afterStart = String(text[start.upperBound...])
        let sectionBody: String
        if let nextSection = afterStart.range(of: "\n## ") {
            sectionBody = String(afterStart[afterStart.startIndex..<nextSection.lowerBound])
        } else {
            sectionBody = afterStart
        }

        try expect(sectionBody.contains("example.com"),
                   "Snippet expansion section should demonstrate with a generic email like `you@example.com`, not a personal one.")
        try expect(!sectionBody.contains("rohin.agrawal@gmail.com"),
                   "Snippet expansion section should not use the maintainer's personal email as the trigger demo — replace with `you@example.com`.")
    }
}
