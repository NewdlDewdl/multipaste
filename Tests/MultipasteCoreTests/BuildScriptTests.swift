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
}
