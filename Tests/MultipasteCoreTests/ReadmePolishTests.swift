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
}
