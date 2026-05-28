// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

enum ScreenshotDetectorTests {

    static func registerAll() {
        TestRegistry.register("ScreenshotDetector/defaultMacosPngName", defaultMacosPngName)
        TestRegistry.register("ScreenshotDetector/defaultMacosJpgWhenUserHasChangedType", defaultMacosJpgWhenUserHasChangedType)
        TestRegistry.register("ScreenshotDetector/heicAndTiffAcceptedToo", heicAndTiffAcceptedToo)
        TestRegistry.register("ScreenshotDetector/uppercaseExtensionStillMatches", uppercaseExtensionStillMatches)
        TestRegistry.register("ScreenshotDetector/customPrefixMatches", customPrefixMatches)
        TestRegistry.register("ScreenshotDetector/customPrefixDoesNotMatchScreenshot", customPrefixDoesNotMatchScreenshot)
        TestRegistry.register("ScreenshotDetector/underscoreSeparatedFilenameMatches", underscoreSeparatedFilenameMatches)
        TestRegistry.register("ScreenshotDetector/standalonePrefixWithoutTimestampMatches", standalonePrefixWithoutTimestampMatches)
        TestRegistry.register("ScreenshotDetector/randomTextFileRejected", randomTextFileRejected)
        TestRegistry.register("ScreenshotDetector/randomPngWithoutPrefixRejected", randomPngWithoutPrefixRejected)
        TestRegistry.register("ScreenshotDetector/dotfileRejected", dotfileRejected)
        TestRegistry.register("ScreenshotDetector/emptyFilenameRejected", emptyFilenameRejected)
        TestRegistry.register("ScreenshotDetector/emptyPrefixRejected", emptyPrefixRejected)
        TestRegistry.register("ScreenshotDetector/extensionlessFileRejected", extensionlessFileRejected)
        TestRegistry.register("ScreenshotDetector/prefixMustHaveSeparatorBeforeTimestamp", prefixMustHaveSeparatorBeforeTimestamp)
        TestRegistry.register("ScreenshotDetector/movieRecordingRejected", movieRecordingRejected)

        TestRegistry.register("ScreenshotDetector/resolveLocationDefaultsToDesktop", resolveLocationDefaultsToDesktop)
        TestRegistry.register("ScreenshotDetector/resolveLocationReadsAbsolutePath", resolveLocationReadsAbsolutePath)
        TestRegistry.register("ScreenshotDetector/resolveLocationExpandsTilde", resolveLocationExpandsTilde)
        TestRegistry.register("ScreenshotDetector/resolveLocationEmptyStringFallsBackToDesktop", resolveLocationEmptyStringFallsBackToDesktop)
        TestRegistry.register("ScreenshotDetector/resolveLocationWhitespaceFallsBackToDesktop", resolveLocationWhitespaceFallsBackToDesktop)
        TestRegistry.register("ScreenshotDetector/resolveLocationNilDictionaryFallsBack", resolveLocationNilDictionaryFallsBack)

        TestRegistry.register("ScreenshotDetector/resolvePrefixDefaultsToScreenshot", resolvePrefixDefaultsToScreenshot)
        TestRegistry.register("ScreenshotDetector/resolvePrefixReadsCustomName", resolvePrefixReadsCustomName)
        TestRegistry.register("ScreenshotDetector/resolvePrefixEmptyFallsBack", resolvePrefixEmptyFallsBack)
        TestRegistry.register("ScreenshotDetector/resolvePrefixWhitespaceFallsBack", resolvePrefixWhitespaceFallsBack)
        TestRegistry.register("ScreenshotDetector/resolvePrefixTrimsSurroundingWhitespace", resolvePrefixTrimsSurroundingWhitespace)

        TestRegistry.register("ScreenshotDetector/filterNewScreenshotsBasicCase", filterNewScreenshotsBasicCase)
        TestRegistry.register("ScreenshotDetector/filterNewScreenshotsExcludesKnown", filterNewScreenshotsExcludesKnown)
        TestRegistry.register("ScreenshotDetector/filterNewScreenshotsIgnoresNonMatches", filterNewScreenshotsIgnoresNonMatches)
        TestRegistry.register("ScreenshotDetector/filterNewScreenshotsHonorsCustomPrefix", filterNewScreenshotsHonorsCustomPrefix)
        TestRegistry.register("ScreenshotDetector/filterNewScreenshotsEmptyDirectory", filterNewScreenshotsEmptyDirectory)
    }

    // MARK: - isLikelyScreenshot

    static func defaultMacosPngName() throws {
        try expect(ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.png"))
    }

    static func defaultMacosJpgWhenUserHasChangedType() throws {
        try expect(ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.jpg"))
        try expect(ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.jpeg"))
    }

    static func heicAndTiffAcceptedToo() throws {
        try expect(ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.heic"))
        try expect(ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.tiff"))
        try expect(ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.tif"))
        // Preview can re-export to PDF; some Markup workflows write PDF too.
        try expect(ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.pdf"))
    }

    static func uppercaseExtensionStillMatches() throws {
        try expect(ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.PNG"),
                   "extensions are case-insensitive — macOS Preview sometimes uppercases on re-export")
    }

    static func customPrefixMatches() throws {
        try expect(ScreenshotDetector.isLikelyScreenshot(
            filename: "MyShot 2026-05-28 at 10.13.42 AM.png",
            screencapturePrefix: "MyShot"))
    }

    static func customPrefixDoesNotMatchScreenshot() throws {
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.png",
            screencapturePrefix: "MyShot"),
                   "if user has set a non-default prefix, default 'Screenshot' files don't match")
    }

    static func underscoreSeparatedFilenameMatches() throws {
        // Some third-party screenshot tools (CleanShot etc.) write
        // underscore-joined names matching the macOS prefix convention.
        try expect(ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot_2026-05-28_at_10.13.42.png"))
    }

    static func standalonePrefixWithoutTimestampMatches() throws {
        // Just `Screenshot.png` (no timestamp suffix). Rare but valid.
        try expect(ScreenshotDetector.isLikelyScreenshot(filename: "Screenshot.png"))
    }

    static func randomTextFileRejected() throws {
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "notes.txt"))
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.txt"),
                   ".txt is not a recognized screenshot extension even with the prefix")
    }

    static func randomPngWithoutPrefixRejected() throws {
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "my-cat-photo.png"))
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "diagram.png"))
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "design-mockup.png"))
    }

    static func dotfileRejected() throws {
        // Finder writes `.Screenshot 2026-05-28 at...` as a temp dotfile
        // during atomic-rename. We must not race on the temp file.
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: ".Screenshot 2026-05-28 at 10.13.42 AM.png"))
    }

    static func emptyFilenameRejected() throws {
        try expect(!ScreenshotDetector.isLikelyScreenshot(filename: ""))
    }

    static func emptyPrefixRejected() throws {
        // Empty prefix would match every file with a recognized ext —
        // a denial-of-service waiting to happen.
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "anything.png",
            screencapturePrefix: ""))
    }

    static func extensionlessFileRejected() throws {
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot"),
                   "no extension → can't be an image — even the standalone-prefix case requires an ext")
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28"))
    }

    static func prefixMustHaveSeparatorBeforeTimestamp() throws {
        // Reject `Screenshots ...png` — the prefix is "Screenshot" not
        // "Screenshots", so a file beginning with "Screenshots" is a
        // different file.
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshots-from-the-week.png"),
                   "'Screenshots' (with trailing s) is not the configured prefix")
        // Same for an immediate alpha char (e.g. "Screenshotgallery.png").
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshotgallery.png"))
    }

    static func movieRecordingRejected() throws {
        // Screen recordings (⌘⇧5 → Record) write .mov, not an image
        // format. We intentionally don't auto-copy them — they can't
        // be inline-pasted as image data and aren't useful in clipboard
        // history.
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "Screen Recording 2026-05-28 at 10.13.42 AM.mov"))
        // Also reject if the user has used a custom screenshot prefix
        // but the file is still .mov.
        try expect(!ScreenshotDetector.isLikelyScreenshot(
            filename: "Screenshot 2026-05-28 at 10.13.42 AM.mov"))
    }

    // MARK: - resolveLocation

    static func resolveLocationDefaultsToDesktop() throws {
        let home = URL(fileURLWithPath: "/Users/x")
        let loc = ScreenshotDetector.resolveLocation(
            screenCaptureDefaults: nil, home: home)
        try expectEqual(loc.path, "/Users/x/Desktop")
    }

    static func resolveLocationReadsAbsolutePath() throws {
        let home = URL(fileURLWithPath: "/Users/x")
        let dict: [String: Any] = ["location": "/Users/x/Pictures/Screenshots"]
        let loc = ScreenshotDetector.resolveLocation(
            screenCaptureDefaults: dict, home: home)
        try expectEqual(loc.path, "/Users/x/Pictures/Screenshots")
    }

    static func resolveLocationExpandsTilde() throws {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let dict: [String: Any] = ["location": "~/Pictures/Screenshots"]
        let loc = ScreenshotDetector.resolveLocation(
            screenCaptureDefaults: dict, home: home)
        try expectEqual(loc.path,
                        NSHomeDirectory() + "/Pictures/Screenshots",
                        "~ in the location must expand to $HOME")
    }

    static func resolveLocationEmptyStringFallsBackToDesktop() throws {
        let home = URL(fileURLWithPath: "/Users/x")
        let dict: [String: Any] = ["location": ""]
        let loc = ScreenshotDetector.resolveLocation(
            screenCaptureDefaults: dict, home: home)
        try expectEqual(loc.path, "/Users/x/Desktop")
    }

    static func resolveLocationWhitespaceFallsBackToDesktop() throws {
        let home = URL(fileURLWithPath: "/Users/x")
        let dict: [String: Any] = ["location": "   \t  \n"]
        let loc = ScreenshotDetector.resolveLocation(
            screenCaptureDefaults: dict, home: home)
        try expectEqual(loc.path, "/Users/x/Desktop")
    }

    static func resolveLocationNilDictionaryFallsBack() throws {
        let home = URL(fileURLWithPath: "/Users/x")
        let loc = ScreenshotDetector.resolveLocation(
            screenCaptureDefaults: nil, home: home)
        try expectEqual(loc.path, "/Users/x/Desktop")
    }

    // MARK: - resolvePrefix

    static func resolvePrefixDefaultsToScreenshot() throws {
        try expectEqual(
            ScreenshotDetector.resolvePrefix(screenCaptureDefaults: nil),
            "Screenshot")
    }

    static func resolvePrefixReadsCustomName() throws {
        try expectEqual(
            ScreenshotDetector.resolvePrefix(
                screenCaptureDefaults: ["name": "MyShot"]),
            "MyShot")
    }

    static func resolvePrefixEmptyFallsBack() throws {
        try expectEqual(
            ScreenshotDetector.resolvePrefix(
                screenCaptureDefaults: ["name": ""]),
            "Screenshot")
    }

    static func resolvePrefixWhitespaceFallsBack() throws {
        try expectEqual(
            ScreenshotDetector.resolvePrefix(
                screenCaptureDefaults: ["name": "   "]),
            "Screenshot")
    }

    static func resolvePrefixTrimsSurroundingWhitespace() throws {
        // Some users do `defaults write com.apple.screencapture name ' Foo '`
        // by accident — strip surrounding whitespace so we don't end up
        // matching ` Foo 2026-...png` (impossible by way of leading space).
        try expectEqual(
            ScreenshotDetector.resolvePrefix(
                screenCaptureDefaults: ["name": "  Foo  "]),
            "Foo")
    }

    // MARK: - filterNewScreenshots

    static func filterNewScreenshotsBasicCase() throws {
        let dir = URL(fileURLWithPath: "/Users/x/Desktop")
        let result = ScreenshotDetector.filterNewScreenshots(
            in: dir,
            directoryContents: ["Screenshot 2026-05-28 at 10.13.42 AM.png"],
            knownPaths: [])
        try expectEqual(result.count, 1)
        try expectEqual(result[0].path,
                        "/Users/x/Desktop/Screenshot 2026-05-28 at 10.13.42 AM.png")
    }

    static func filterNewScreenshotsExcludesKnown() throws {
        let dir = URL(fileURLWithPath: "/Users/x/Desktop")
        let existing = "/Users/x/Desktop/Screenshot 2026-05-28 at 10.13.42 AM.png"
        let result = ScreenshotDetector.filterNewScreenshots(
            in: dir,
            directoryContents: ["Screenshot 2026-05-28 at 10.13.42 AM.png",
                                "Screenshot 2026-05-28 at 10.14.05 AM.png"],
            knownPaths: [existing])
        try expectEqual(result.count, 1, "the known one is suppressed")
        try expectEqual(result[0].lastPathComponent,
                        "Screenshot 2026-05-28 at 10.14.05 AM.png")
    }

    static func filterNewScreenshotsIgnoresNonMatches() throws {
        let dir = URL(fileURLWithPath: "/Users/x/Desktop")
        let result = ScreenshotDetector.filterNewScreenshots(
            in: dir,
            directoryContents: ["random.txt",
                                "vacation.png",
                                ".DS_Store",
                                "Screenshot 2026-05-28 at 10.13.42 AM.png"],
            knownPaths: [])
        try expectEqual(result.count, 1, "only the screenshot is selected")
        try expectEqual(result[0].lastPathComponent,
                        "Screenshot 2026-05-28 at 10.13.42 AM.png")
    }

    static func filterNewScreenshotsHonorsCustomPrefix() throws {
        let dir = URL(fileURLWithPath: "/Users/x/Desktop")
        let result = ScreenshotDetector.filterNewScreenshots(
            in: dir,
            directoryContents: ["MyShot 2026-05-28 at 10.13.42 AM.png",
                                "Screenshot 2026-05-28 at 10.13.42 AM.png"],
            knownPaths: [],
            screencapturePrefix: "MyShot")
        try expectEqual(result.count, 1, "only the custom-prefix one matches")
        try expectEqual(result[0].lastPathComponent,
                        "MyShot 2026-05-28 at 10.13.42 AM.png")
    }

    static func filterNewScreenshotsEmptyDirectory() throws {
        let dir = URL(fileURLWithPath: "/Users/x/Desktop")
        let result = ScreenshotDetector.filterNewScreenshots(
            in: dir, directoryContents: [], knownPaths: [])
        try expect(result.isEmpty)
    }
}
