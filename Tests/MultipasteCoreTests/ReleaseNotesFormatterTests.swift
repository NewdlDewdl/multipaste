// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

enum ReleaseNotesFormatterTests {

    static func registerAll() {
        // summary(from:)
        TestRegistry.register("ReleaseNotesFormatter/summaryStripsVersionHeader", summaryStripsVersionHeader)
        TestRegistry.register("ReleaseNotesFormatter/summaryStopsAtFirstH3", summaryStopsAtFirstH3)
        TestRegistry.register("ReleaseNotesFormatter/summaryStopsAtSecondVersionEntry", summaryStopsAtSecondVersionEntry)
        TestRegistry.register("ReleaseNotesFormatter/summaryNoHeaderReturnsAllText", summaryNoHeaderReturnsAllText)
        TestRegistry.register("ReleaseNotesFormatter/summaryEmptyInputReturnsEmpty", summaryEmptyInputReturnsEmpty)
        TestRegistry.register("ReleaseNotesFormatter/summaryStripsBlankLineAfterVersionHeader", summaryStripsBlankLineAfterVersionHeader)
        TestRegistry.register("ReleaseNotesFormatter/summaryTrimsTrailingWhitespace", summaryTrimsTrailingWhitespace)
        TestRegistry.register("ReleaseNotesFormatter/summaryPreservesInlineMarkdown", summaryPreservesInlineMarkdown)
        TestRegistry.register("ReleaseNotesFormatter/summaryHandlesV210ChangelogEntry", summaryHandlesV210ChangelogEntry)

        // cleanPlainText(from:)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextStripsBold", cleanPlainTextStripsBold)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextStripsItalic", cleanPlainTextStripsItalic)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextStripsInlineCode", cleanPlainTextStripsInlineCode)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextStripsHeaders", cleanPlainTextStripsHeaders)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextStripsBlockquoteMarker", cleanPlainTextStripsBlockquoteMarker)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextConvertsBulletsToDots", cleanPlainTextConvertsBulletsToDots)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextUnwrapsLinks", cleanPlainTextUnwrapsLinks)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextLeavesUnmatchedDelimitersAlone", cleanPlainTextLeavesUnmatchedDelimitersAlone)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextHandlesMixedFormatting", cleanPlainTextHandlesMixedFormatting)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextEmptyInput", cleanPlainTextEmptyInput)
        TestRegistry.register("ReleaseNotesFormatter/cleanPlainTextV202DialogBugRegression", cleanPlainTextV202DialogBugRegression)
    }

    // MARK: - summary

    static func summaryStripsVersionHeader() throws {
        let input = """
        ## 2.1.0 — 2026-05-28

        New feature: auto-copy screenshots.
        """
        try expectEqual(
            ReleaseNotesFormatter.summary(from: input),
            "New feature: auto-copy screenshots.")
    }

    static func summaryStopsAtFirstH3() throws {
        let input = """
        ## 2.1.0 — 2026-05-28

        Top-level value prop here.

        Maybe a follow-up paragraph too.

        ### How it works

        Engineer detail
        """
        let out = ReleaseNotesFormatter.summary(from: input)
        try expect(out.contains("Top-level value prop"))
        try expect(out.contains("follow-up paragraph"))
        try expect(!out.contains("How it works"),
                   "h3 header itself must be excluded")
        try expect(!out.contains("Engineer detail"),
                   "post-h3 content must be excluded")
    }

    static func summaryStopsAtSecondVersionEntry() throws {
        let input = """
        ## 2.1.0 — 2026-05-28

        New stuff.

        ## 2.0.2 — 2026-05-16

        Old stuff
        """
        let out = ReleaseNotesFormatter.summary(from: input)
        try expectEqual(out, "New stuff.",
                        "must extract only the latest entry — don't dump the full changelog")
    }

    static func summaryNoHeaderReturnsAllText() throws {
        let input = "Just a release-body paragraph without any markdown headers."
        try expectEqual(
            ReleaseNotesFormatter.summary(from: input),
            "Just a release-body paragraph without any markdown headers.")
    }

    static func summaryEmptyInputReturnsEmpty() throws {
        try expectEqual(ReleaseNotesFormatter.summary(from: ""), "")
        try expectEqual(ReleaseNotesFormatter.summary(from: "\n\n  \n"), "")
    }

    static func summaryStripsBlankLineAfterVersionHeader() throws {
        let input = """
        ## 2.1.0 — 2026-05-28


        Content
        """
        try expectEqual(ReleaseNotesFormatter.summary(from: input), "Content")
    }

    static func summaryTrimsTrailingWhitespace() throws {
        let input = """
        ## 2.1.0 — 2026-05-28

        Body.



        """
        try expectEqual(ReleaseNotesFormatter.summary(from: input), "Body.")
    }

    static func summaryPreservesInlineMarkdown() throws {
        // The summary extractor is purely a block-level slicer; it must
        // NOT touch inline markdown (the renderer handles that later).
        let input = """
        ## 2.1.0 — 2026-05-28

        Feature: **bold thing** with `code` and *emphasis*.
        """
        let out = ReleaseNotesFormatter.summary(from: input)
        try expect(out.contains("**bold thing**"))
        try expect(out.contains("`code`"))
        try expect(out.contains("*emphasis*"))
    }

    static func summaryHandlesV210ChangelogEntry() throws {
        // The real-world shape of the v2.1.0 CHANGELOG entry — what the
        // dialog WILL show. Verify it produces the user-facing summary
        // and drops the engineer detail.
        let input = """
        ## 2.1.0 — 2026-05-28

        New feature: **auto-copy screenshots to clipboard**. macOS's default screenshot workflow saves to disk; users had to remember ⌃⌘⇧4 to also get it on the clipboard. Multipaste now auto-copies every screenshot.

        ### How it works

        1. Read `defaults read com.apple.screencapture` …

        ### What changed

        - `Sources/MultipasteCore/ScreenshotDetector.swift` …
        """
        let out = ReleaseNotesFormatter.summary(from: input)
        try expect(out.contains("auto-copy screenshots"))
        try expect(out.contains("⌃⌘⇧4"))
        try expect(!out.contains("How it works"))
        try expect(!out.contains("ScreenshotDetector.swift"))
        try expect(!out.contains("defaults read"),
                   "post-h3 code block must not leak into the summary")
    }

    // MARK: - cleanPlainText

    static func cleanPlainTextStripsBold() throws {
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "Hello **world**!"),
            "Hello world!")
    }

    static func cleanPlainTextStripsItalic() throws {
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "Hello *world*!"),
            "Hello world!")
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "Hello _world_!"),
            "Hello world!")
    }

    static func cleanPlainTextStripsInlineCode() throws {
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "Use `cmd-v` to paste."),
            "Use cmd-v to paste.")
    }

    static func cleanPlainTextStripsHeaders() throws {
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "## 2.1.0\n### The bug\nA bug"),
            "2.1.0\nThe bug\nA bug")
    }

    static func cleanPlainTextStripsBlockquoteMarker() throws {
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "> quoted line\n> another"),
            "quoted line\nanother")
    }

    static func cleanPlainTextConvertsBulletsToDots() throws {
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "- one\n- two"),
            "• one\n• two")
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "* alt one\n* alt two"),
            "• alt one\n• alt two")
    }

    static func cleanPlainTextUnwrapsLinks() throws {
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "See [the docs](https://example.com)."),
            "See the docs (https://example.com).")
    }

    static func cleanPlainTextLeavesUnmatchedDelimitersAlone() throws {
        // Conservative: don't try to repair broken markdown — leave it.
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "value is 3*5"),
            "value is 3*5",
            "no italic match → leave the * alone")
        try expectEqual(
            ReleaseNotesFormatter.cleanPlainText(from: "open `but no close"),
            "open `but no close",
            "unclosed backtick → leave it")
    }

    static func cleanPlainTextHandlesMixedFormatting() throws {
        let input = """
        ## 2.0.2 — 2026-05-16

        Hotfix: the **in-DMG `READ ME FIRST.txt`** told users to double-click.

        ### The bug

        Multipaste is ad-hoc signed (no Apple Developer ID).
        """
        let out = ReleaseNotesFormatter.cleanPlainText(from: input)
        try expect(out.contains("2.0.2"))
        try expect(!out.contains("##"))
        try expect(!out.contains("**"))
        try expect(!out.contains("`READ ME FIRST.txt`"),
                   "the inline-code-INSIDE-bold case must also be stripped")
        try expect(out.contains("READ ME FIRST.txt"))
        try expect(out.contains("The bug"))
        try expect(out.contains("ad-hoc signed"))
    }

    static func cleanPlainTextEmptyInput() throws {
        try expectEqual(ReleaseNotesFormatter.cleanPlainText(from: ""), "")
    }

    /// Regression guard for the dialog screenshot Rohin reported: the
    /// v2.0.2 update notification showed raw `## 2.0.2 — 2026-05-16`,
    /// `**in-DMG `READ ME FIRST.txt`**`, `### The bug`, `>` blockquotes,
    /// and `[Cancel]` brackets as literal characters in an
    /// `NSAlert.informativeText`. After this fix, `cleanPlainText`
    /// strips every markdown sigil and the renderer can re-style the
    /// content properly.
    static func cleanPlainTextV202DialogBugRegression() throws {
        let realChangelog202 = """
        ## 2.0.2 — 2026-05-16

        Hotfix: the **in-DMG `READ ME FIRST.txt`** told users to double-click Multipaste on first launch — which doesn't work for an ad-hoc-signed app downloaded from the internet.

        ### The bug

        Multipaste is ad-hoc signed (no Apple Developer ID — we'd need a $99/yr Apple Developer Program membership for that). Apps without Developer ID signing trigger Gatekeeper on first launch. When a user double-clicks the app, macOS shows:

        > "Multipaste cannot be opened because the developer cannot be verified."
        >
        > [Cancel] [Move to Bin]

        **There is no Open button.**
        """
        let out = ReleaseNotesFormatter.cleanPlainText(from: realChangelog202)

        // None of the markdown sigils should survive.
        try expect(!out.contains("**"),
                   "bold sigil must be stripped (was visible in dialog screenshot)")
        try expect(!out.contains("##"),
                   "header sigil must be stripped (was visible in dialog screenshot)")
        try expect(!out.contains("`READ ME FIRST.txt`"),
                   "inline-code-inside-bold must be stripped")
        try expect(!out.contains("> \""),
                   "blockquote marker must be stripped")

        // The actual content should survive.
        try expect(out.contains("Hotfix"))
        try expect(out.contains("READ ME FIRST.txt"))
        try expect(out.contains("There is no Open button"))
        try expect(out.contains("[Cancel] [Move to Bin]"),
                   "literal square brackets that aren't part of markdown link syntax stay as-is")
    }
}
