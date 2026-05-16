// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

// Verifies scripts/build.sh produces a UNIVERSAL binary (arm64 + x86_64)
// by default — and fails loudly at build time if a single-arch build
// silently slips through.
//
// Why this exists: Multipaste v2.0.0 shipped an arm64-only DMG because
// build.sh hard-coded the build host's architecture. A friend on
// macOS Ventura 13.7.8 (Intel) downloaded it and got the macOS error:
//   "You can't open the application 'Multipaste' because this
//    application is not supported on this Mac."
// That's the exact wording macOS shows for an arch mismatch (not a
// version mismatch). Fixed in v2.0.1 by building both archs and using
// `lipo -create` to produce a fat Mach-O.
//
// This Swift suite locks in the FIX SHAPE (the build script defaults to
// universal + verifies the embedded binary at build time). The actual
// universal-binary runtime check lives in build.sh itself — it runs
// `lipo -archs` on the assembled bundle and fails the script if any
// requested arch is missing. That makes the bug class impossible to
// ship even from a single-arch developer machine.

enum BuildScriptTests {

    static func registerAll() {
        TestRegistry.register("BuildScript/buildShDefaultsToUniversal", buildShDefaultsToUniversal)
        TestRegistry.register("BuildScript/buildShVerifiesEmbeddedArchitectures", buildShVerifiesEmbeddedArchitectures)
        TestRegistry.register("BuildScript/dmgReadmeUsesControlClickNotDoubleClick", dmgReadmeUsesControlClickNotDoubleClick)
        TestRegistry.register("BuildScript/dmgReadmeMentionsSystemSettingsFallback", dmgReadmeMentionsSystemSettingsFallback)
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/Tests/MultipasteCoreTests
            .deletingLastPathComponent()   // …/Tests
            .deletingLastPathComponent()   // …/<packageRoot>
    }

    private static func read(_ relativePath: String) throws -> String {
        let url = packageRoot.appendingPathComponent(relativePath)
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw TestFailure(
                message: "Failed to read \(relativePath): \(error)",
                file: #file, line: #line)
        }
    }

    // The default `ARCHS` in build.sh must include BOTH arm64 and x86_64,
    // so a fresh `bash scripts/build.sh` produces a universal binary
    // without the developer remembering to set MULTIPASTE_BUILD_ARCHS.
    static func buildShDefaultsToUniversal() throws {
        let script = try read("scripts/build.sh")

        try expect(script.contains("MULTIPASTE_BUILD_ARCHS"),
                   "build.sh missing the MULTIPASTE_BUILD_ARCHS override hook")

        // Look for `${MULTIPASTE_BUILD_ARCHS:-arm64 x86_64}` (or the
        // equivalent with the args in either order — but in practice the
        // single canonical default in build.sh is `arm64 x86_64`).
        let universalDefault = "${MULTIPASTE_BUILD_ARCHS:-arm64 x86_64}"
        try expect(script.contains(universalDefault),
                   "build.sh default architectures must be `arm64 x86_64` (universal). Got something else — a single-arch default ships broken DMGs to Intel or Apple Silicon users.")

        // The two arch flags must both appear in the build loop too.
        try expect(script.contains("--arch \"$ARCH\"") || script.contains("--arch $ARCH"),
                   "build.sh must invoke `swift build` with --arch for each architecture")
    }

    // The lipo-verification step at the end of build.sh runs
    // `lipo -archs` on the assembled bundle and fails if any requested
    // arch is missing. This is the load-bearing regression guard — even
    // if someone breaks the default ARCHS value, this step catches a
    // missing arch before the DMG is even built.
    static func buildShVerifiesEmbeddedArchitectures() throws {
        let script = try read("scripts/build.sh")

        try expect(script.contains("lipo -create"),
                   "build.sh must combine per-arch binaries with `lipo -create`")
        try expect(script.contains("lipo -archs"),
                   "build.sh must verify the embedded architectures with `lipo -archs` after assembly")
        // The verification should iterate over requested archs and fail
        // if any are missing. Look for the failure mode wording or `exit 1`
        // in proximity to the arch-check loop.
        try expect(script.contains("built binary missing requested architecture"),
                   "build.sh must fail with a descriptive message if an arch is missing from the embedded binary")
    }

    // The in-DMG "READ ME FIRST.txt" tells users how to launch the
    // app for the first time. Multipaste is ad-hoc signed (no Apple
    // Developer ID), so on first launch Gatekeeper rejects a double-
    // click with "Multipaste cannot be opened" — and the dialog has
    // NO Open button, only Cancel + Move to Bin. The user MUST
    // control-click (or right-click) → Open to get the dialog that
    // does have an Open button. v2.0.2 fixed the in-DMG README which
    // had said "double-click" at step 2 → user stuck immediately.
    // These two tests catch any future edit that reintroduces the
    // broken "just double-click" wording.
    static func dmgReadmeUsesControlClickNotDoubleClick() throws {
        let script = try read("scripts/dmg.sh")
        // Locate the heredoc that defines the in-DMG README.
        guard let start = script.range(of: "READ ME FIRST.txt\" <<EOF"),
              let end = script.range(of: "\nEOF\n", range: start.upperBound..<script.endIndex) else {
            throw TestFailure(
                message: "Could not locate the in-DMG README heredoc in scripts/dmg.sh",
                file: #file, line: #line)
        }
        let readme = String(script[start.upperBound..<end.lowerBound])

        // Must explicitly mention control-click or right-click as the
        // first-launch instruction. "control-click" is the Apple
        // canonical term but accept either to be permissive.
        let mentionsControlClick = readme.lowercased().contains("control-click") ||
                                   readme.lowercased().contains("right-click")
        try expect(mentionsControlClick,
                   "in-DMG README must instruct users to control-click (or right-click) on first launch — double-click hits a Gatekeeper dialog with NO Open button for ad-hoc signed apps")

        // Must reference the Open button (control-click → Open) so
        // users know what to click in the resulting dialog.
        try expect(readme.contains("Open"),
                   "in-DMG README must mention the Open button in the control-click flow")

        // Must NOT instruct the user to ONLY double-click as the
        // primary install step (the v2.0.1-and-earlier bug).
        // Detection: look for the specific instruction wording that
        // would mislead users. "double-click" appearing in
        // explanatory text (like "every subsequent launch is an
        // ordinary double-click") is fine — what we forbid is the
        // step-2-instruction form.
        try expect(!readme.contains("double-click Multipaste"),
                   "in-DMG README must NOT instruct users to double-click Multipaste as the first-launch action — that's the v2.0.1-era bug. Use control-click → Open instead.")
    }

    static func dmgReadmeMentionsSystemSettingsFallback() throws {
        let script = try read("scripts/dmg.sh")
        guard let start = script.range(of: "READ ME FIRST.txt\" <<EOF"),
              let end = script.range(of: "\nEOF\n", range: start.upperBound..<script.endIndex) else {
            throw TestFailure(
                message: "Could not locate the in-DMG README heredoc in scripts/dmg.sh",
                file: #file, line: #line)
        }
        let readme = String(script[start.upperBound..<end.lowerBound])

        // On macOS 15 Sequoia, the control-click → Open route has
        // been progressively hardened. The fallback is System
        // Settings → Privacy & Security → "Open Anyway". The in-DMG
        // README should mention this so Sequoia users who get
        // stuck on control-click have a documented escape.
        try expect(readme.contains("System Settings"),
                   "in-DMG README should mention System Settings → Privacy & Security as a Gatekeeper fallback (control-click → Open is being hardened on macOS 15 Sequoia)")
        try expect(readme.contains("Open Anyway") || readme.contains("Privacy"),
                   "in-DMG README should reference the \"Open Anyway\" button in System Settings → Privacy & Security")
    }
}
