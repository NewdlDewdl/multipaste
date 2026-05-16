// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

// Verifies PolyForm-recommended licensing metadata: REUSE Specification
// compliance, .licensee.json detection config, LICENSES/ directory with
// REUSE-canonical filename, SPDX headers in every Swift source file, and
// the PolyForm Strict badge in README.
//
// Why this matters: PolyForm Strict 1.0.0 is not on the SPDX standard
// license list (only PolyForm-Noncommercial-1.0.0 and PolyForm-Small-
// Business-1.0.0 are). For automated license-detection tools (licensee,
// FOSSology, scancode, GitHub's license-detection, REUSE tool) to
// correctly identify the license, the project must declare it via the
// SPDX `LicenseRef-PolyForm-Strict-1.0.0` convention in multiple places:
//   - REUSE.toml (for the REUSE Specification)
//   - .licensee.json (for the licensee gem)
//   - LICENSES/LicenseRef-PolyForm-Strict-1.0.0.md (for REUSE discovery)
//   - SPDX-License-Identifier comment in every source file
// These tests lock all of that in so a careless edit can't silently
// break license-detection downstream.

enum LicensingMetadataTests {

    static let spdxIdentifier = "LicenseRef-PolyForm-Strict-1.0.0"
    static let polyformCanonicalURL = "https://polyformproject.org/licenses/strict/1.0.0"
    static let polyformBadgeURL = "https://polyformproject.org/strict.png"

    static func registerAll() {
        TestRegistry.register("LicensingMetadata/reuseTomlExists", reuseTomlExists)
        TestRegistry.register("LicensingMetadata/reuseTomlDeclaresPolyFormStrict", reuseTomlDeclaresPolyFormStrict)
        TestRegistry.register("LicensingMetadata/licenseeJsonExists", licenseeJsonExists)
        TestRegistry.register("LicensingMetadata/licenseeJsonDeclaresPolyFormStrict", licenseeJsonDeclaresPolyFormStrict)
        TestRegistry.register("LicensingMetadata/licensesDirHasReuseCanonicalFile", licensesDirHasReuseCanonicalFile)
        TestRegistry.register("LicensingMetadata/licensesDirFileMatchesLicenseMd", licensesDirFileMatchesLicenseMd)
        TestRegistry.register("LicensingMetadata/allSwiftFilesHaveSPDXLicenseIdentifier", allSwiftFilesHaveSPDXLicenseIdentifier)
        TestRegistry.register("LicensingMetadata/allSwiftFilesHaveSPDXFileCopyrightText", allSwiftFilesHaveSPDXFileCopyrightText)
        TestRegistry.register("LicensingMetadata/packageSwiftHasSPDXHeader", packageSwiftHasSPDXHeader)
        TestRegistry.register("LicensingMetadata/readmeHasPolyFormBadge", readmeHasPolyFormBadge)
        TestRegistry.register("LicensingMetadata/readmeReferencesCanonicalPolyFormURL", readmeReferencesCanonicalPolyFormURL)
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

    // ----- REUSE.toml -----

    static func reuseTomlExists() throws {
        try expect(fileExists("REUSE.toml"),
                   "REUSE.toml not found at package root — required for REUSE Specification compliance")
    }

    static func reuseTomlDeclaresPolyFormStrict() throws {
        let text = try read("REUSE.toml")
        try expect(text.contains("version = 1"),
                   "REUSE.toml missing `version = 1` declaration")
        try expect(text.contains("SPDX-License-Identifier") && text.contains(spdxIdentifier),
                   "REUSE.toml must declare SPDX-License-Identifier = \"\(spdxIdentifier)\"")
        try expect(text.contains("Sources/**/*.swift"),
                   "REUSE.toml must annotate Sources/**/*.swift")
        try expect(text.contains("Tests/**/*.swift"),
                   "REUSE.toml must annotate Tests/**/*.swift")
    }

    // ----- .licensee.json -----

    static func licenseeJsonExists() throws {
        try expect(fileExists(".licensee.json"),
                   ".licensee.json not found at package root")
    }

    static func licenseeJsonDeclaresPolyFormStrict() throws {
        let text = try read(".licensee.json")
        try expect(text.contains(spdxIdentifier),
                   ".licensee.json must declare SPDX identifier \(spdxIdentifier)")
        // Validate it's well-formed JSON so the licensee gem can parse it.
        let data = text.data(using: .utf8) ?? Data()
        let parsed = try? JSONSerialization.jsonObject(with: data, options: [])
        try expect(parsed != nil,
                   ".licensee.json must be valid JSON")
    }

    // ----- LICENSES/ directory (REUSE canonical location) -----

    static func licensesDirHasReuseCanonicalFile() throws {
        try expect(fileExists("LICENSES/LicenseRef-PolyForm-Strict-1.0.0.md"),
                   "LICENSES/LicenseRef-PolyForm-Strict-1.0.0.md not found — REUSE tool will not detect the license")
    }

    // The LICENSES/ file should be a symlink to LICENSE.md (or have
    // identical content). This test guards against the two diverging.
    static func licensesDirFileMatchesLicenseMd() throws {
        let licensesFile = try read("LICENSES/LicenseRef-PolyForm-Strict-1.0.0.md")
        let rootLicense = try read("LICENSE.md")
        try expectEqual(licensesFile, rootLicense,
                        "LICENSES/LicenseRef-PolyForm-Strict-1.0.0.md content drifted from LICENSE.md — should be a symlink")
    }

    // ----- Per-file SPDX headers -----

    // Enumerates every .swift file in Sources/ and Tests/, asserts each
    // contains the SPDX-License-Identifier line in its first 5 lines.
    // First-5-lines check catches not just "is the line present" but
    // also "is it at the top of the file where tools expect it."
    static func allSwiftFilesHaveSPDXLicenseIdentifier() throws {
        let files = try enumerateSwiftFiles()
        var missing: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let head = text.components(separatedBy: "\n").prefix(5).joined(separator: "\n")
            if !head.contains("SPDX-License-Identifier: \(spdxIdentifier)") {
                missing.append(file.lastPathComponent)
            }
        }
        try expect(missing.isEmpty,
                   "\(missing.count) Swift file(s) missing SPDX-License-Identifier in top 5 lines: \(missing.joined(separator: ", "))")
    }

    static func allSwiftFilesHaveSPDXFileCopyrightText() throws {
        let files = try enumerateSwiftFiles()
        var missing: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let head = text.components(separatedBy: "\n").prefix(5).joined(separator: "\n")
            if !head.contains("SPDX-FileCopyrightText") || !head.contains("Rohin Agrawal") {
                missing.append(file.lastPathComponent)
            }
        }
        try expect(missing.isEmpty,
                   "\(missing.count) Swift file(s) missing SPDX-FileCopyrightText in top 5 lines: \(missing.joined(separator: ", "))")
    }

    private static func enumerateSwiftFiles() throws -> [URL] {
        var out: [URL] = []
        for dir in ["Sources", "Tests"] {
            let dirURL = packageRoot.appendingPathComponent(dir)
            let enumerator = FileManager.default.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            while let url = enumerator?.nextObject() as? URL {
                if url.pathExtension == "swift" {
                    out.append(url)
                }
            }
        }
        try expect(!out.isEmpty,
                   "Enumerator returned 0 Swift files under Sources/ and Tests/")
        return out.sorted { $0.path < $1.path }
    }

    // ----- Package.swift -----

    static func packageSwiftHasSPDXHeader() throws {
        let text = try read("Package.swift")
        // The swift-tools-version line must remain first; SPDX comes after.
        try expect(text.hasPrefix("// swift-tools-version:"),
                   "Package.swift must start with `// swift-tools-version:` line (SwiftPM requirement)")
        let head = text.components(separatedBy: "\n").prefix(10).joined(separator: "\n")
        try expect(head.contains("SPDX-License-Identifier: \(spdxIdentifier)"),
                   "Package.swift missing SPDX-License-Identifier in top 10 lines")
        try expect(head.contains("SPDX-FileCopyrightText"),
                   "Package.swift missing SPDX-FileCopyrightText in top 10 lines")
    }

    // ----- README badge + canonical URL -----

    static func readmeHasPolyFormBadge() throws {
        let text = try read("README.md")
        try expect(text.contains(polyformBadgeURL),
                   "README.md missing the PolyForm Strict badge image at \(polyformBadgeURL)")
    }

    static func readmeReferencesCanonicalPolyFormURL() throws {
        let text = try read("README.md")
        try expect(text.contains(polyformCanonicalURL),
                   "README.md missing canonical PolyForm Strict URL \(polyformCanonicalURL)")
    }
}
