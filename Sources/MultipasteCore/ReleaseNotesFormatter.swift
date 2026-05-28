// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Pure helpers for shaping CHANGELOG / GitHub-release-body markdown
/// into something fit for the in-app update dialog.
///
/// CHANGELOG entries serve two audiences:
///   - **Engineers** browsing GitHub Releases — want the full "what
///     changed" with file lists, test counts, and root-cause analysis.
///   - **Users** seeing the in-app "Multipaste 2.1.0 is available"
///     dialog — want a clear 2-3 sentence "what's new" they can read in
///     one breath while deciding whether to click Download.
///
/// Mixing both audiences in the same text leads to the v1.9.0 → v2.0.2
/// dialog screenshot Rohin reported: a wall of `## headers`, `**bold**`
/// syntax, and ```` ``` ```` code fences rendered as literal
/// punctuation because `NSAlert.informativeText` doesn't render
/// markdown.
///
/// This formatter shapes the engineer-oriented changelog into the
/// user-facing summary via the convention that
/// **everything above the first `### ` subsection is the user-facing
/// summary; everything below it is engineer detail.** That gives
/// CHANGELOG authors a single rule to follow when writing entries.
public enum ReleaseNotesFormatter {

    /// Extract the user-facing summary from a CHANGELOG entry / release
    /// body.
    ///
    /// Behavior:
    ///   1. If the input starts with a `## VERSION` heading (the
    ///      conventional `## 2.1.0 — 2026-05-28` line), drop the
    ///      header AND the trailing blank line — the version is
    ///      already shown in the dialog's title bar.
    ///   2. Take everything from there until the first `### ` (h3)
    ///      header. Those subsections (`### How it works`,
    ///      `### What changed`, `### Test count`) are engineer detail
    ///      that doesn't belong in an update dialog.
    ///   3. If a second `## VERSION` heading appears before any `### `
    ///      (i.e. the input contains multiple changelog entries), also
    ///      stop there — we only want the LATEST entry.
    ///   4. Trim leading/trailing whitespace from the result.
    ///
    /// If the input has no `## ` header AND no `### ` header, the
    /// entire input is returned trimmed — that's the "GitHub release
    /// body is just a paragraph" case.
    public static func summary(from notes: String) -> String {
        var lines = notes.components(separatedBy: "\n")

        // Step 1: skip a leading `## VERSION` header (and the blank line
        // that conventionally follows it). Only strip ONE — multiple
        // ## headers mean the input is the full changelog, in which
        // case step 3 below handles the second-and-beyond.
        if let first = lines.first, first.hasPrefix("## ") {
            lines.removeFirst()
            while let next = lines.first,
                  next.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.removeFirst()
            }
        }

        // Step 2 + 3: collect lines up to the first `### ` (h3 — engineer
        // detail) or a second `## ` (next changelog entry).
        var out: [String] = []
        for line in lines {
            if line.hasPrefix("### ") { break }
            if line.hasPrefix("## ")  { break }
            out.append(line)
        }

        return out.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Fallback: convert markdown to clean ASCII-y plain text by
    /// stripping the syntax punctuation. Useful when the host's
    /// markdown renderer is unavailable (e.g. macOS 11) or when we
    /// want a single-line representation.
    ///
    /// Handled patterns:
    ///   - `**bold**`           → `bold`
    ///   - `*italic*`           → `italic`
    ///   - `` `code` ``         → `code`
    ///   - `[text](url)`        → `text (url)`
    ///   - `> quoted line`      → `quoted line`  (leading `> ` stripped)
    ///   - `- bullet`           → `• bullet`
    ///   - `## heading` /  `### subheading` → text only (markers stripped)
    ///
    /// Conservative on edge cases — leaves unmatched `*` / unmatched
    /// `` ` `` alone rather than trying to repair them.
    public static func cleanPlainText(from markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")

        // Per-line block-syntax transforms.
        for i in 0..<lines.count {
            var line = lines[i]
            // Strip leading header markers.
            if line.hasPrefix("###### ") { line = String(line.dropFirst(7)) }
            else if line.hasPrefix("##### ") { line = String(line.dropFirst(6)) }
            else if line.hasPrefix("#### ") { line = String(line.dropFirst(5)) }
            else if line.hasPrefix("### ") { line = String(line.dropFirst(4)) }
            else if line.hasPrefix("## ") { line = String(line.dropFirst(3)) }
            else if line.hasPrefix("# ") { line = String(line.dropFirst(2)) }
            // Blockquote prefix → strip.
            if line.hasPrefix("> ") { line = String(line.dropFirst(2)) }
            else if line == ">" { line = "" }
            // Bullet → bullet character (the unicode • renders fine in
            // plain text and signals list-ness).
            if line.hasPrefix("- ") { line = "• " + line.dropFirst(2) }
            else if line.hasPrefix("* ") { line = "• " + line.dropFirst(2) }
            lines[i] = line
        }

        var text = lines.joined(separator: "\n")

        // Inline patterns: do bold BEFORE italic so `**foo**` doesn't get
        // half-eaten by the italic matcher.
        text = stripDoubleDelimited(text, delimiter: "**")
        text = stripDoubleDelimited(text, delimiter: "__")
        text = stripSingleDelimited(text, delimiter: "*")
        text = stripSingleDelimited(text, delimiter: "_")
        text = stripSingleDelimited(text, delimiter: "`")
        text = unwrapLinks(text)

        return text
    }

    // MARK: - Inline helpers

    private static func stripDoubleDelimited(_ s: String, delimiter: String) -> String {
        // Matches `delim<content>delim` where content doesn't contain delim.
        // Uses a regex anchored on the literal delimiter; greedy but bounded
        // by the next occurrence of the same delim.
        guard let regex = try? NSRegularExpression(
            pattern: "\(NSRegularExpression.escapedPattern(for: delimiter))(.+?)\(NSRegularExpression.escapedPattern(for: delimiter))",
            options: [.dotMatchesLineSeparators]
        ) else { return s }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "$1")
    }

    private static func stripSingleDelimited(_ s: String, delimiter: String) -> String {
        // For single-char delimiters we want to avoid eating doubled
        // ones (which the caller will have already handled). Match
        // delim<content>delim where delim is a single char and content
        // doesn't start/end with delim and is non-empty.
        let d = NSRegularExpression.escapedPattern(for: delimiter)
        guard let regex = try? NSRegularExpression(
            pattern: "(?<!\(d))\(d)([^\(d)\n]+)\(d)(?!\(d))",
            options: []
        ) else { return s }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "$1")
    }

    private static func unwrapLinks(_ s: String) -> String {
        // [text](url) → text (url)
        guard let regex = try? NSRegularExpression(
            pattern: #"\[([^\]]+)\]\(([^)]+)\)"#,
            options: []
        ) else { return s }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return regex.stringByReplacingMatches(in: s, options: [], range: range,
                                              withTemplate: "$1 ($2)")
    }
}
