// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import Foundation

/// Render inline markdown — bold, italic, inline code, links — to an
/// `NSAttributedString` suitable for display in an `NSAlert.accessoryView`
/// or any other AppKit text control.
///
/// ## Why this exists
///
/// The "Multipaste vX.Y.Z is available" dialog historically stuffed the
/// raw CHANGELOG entry into `NSAlert.informativeText`. That field is
/// plain-text only — it doesn't render markdown — so users saw a wall
/// of literal `##`, `**`, ``` ` ```, `>`, and `[Cancel]` brackets in
/// the dialog instead of formatted release notes. Reported by Rohin
/// 2026-05-28 with a screenshot of the v2.0.2 update dialog showing
/// the bug.
///
/// ## What we render
///
/// - `**bold**` / `__bold__` → bold font
/// - `*italic*` / `_italic_` → italic font
/// - `` `inline code` `` → monospaced font + subtle background tint
/// - `[link text](https://…)` → blue + underline + clickable
///
/// We DON'T render block-level markdown (headers, lists, blockquotes,
/// fenced code) because the dialog only ever displays the user-facing
/// summary, and the `ReleaseNotesFormatter.summary` extractor in
/// `MultipasteCore` stops at the first `### ` header — meaning the
/// content passed in here is already inline-only by construction.
/// Future enhancement could swap `interpretedSyntax: .inlineOnly` for
/// `.full` and add block-level styling; for now, inline is sufficient
/// and the simpler code path.
///
/// ## Why we don't use `NSAttributedString(markdown:)` directly
///
/// macOS 12+ ships `AttributedString(markdown:)` (Foundation, Swift-
/// native) and a bridge to `NSAttributedString`. The bridge translates
/// `inlinePresentationIntent` attributes to *some* visual attributes
/// but the actual font handling is inconsistent across macOS versions
/// — bold sometimes works, code rarely does. Doing the run-walk
/// ourselves gives deterministic results and lets us pick the typography
/// (monospaced font for code, background tint, link color) to match
/// the rest of Multipaste's UI.
enum MarkdownAttributedString {

    /// Render `text` to an `NSAttributedString` with inline markdown
    /// applied. Falls back to plain text via `cleanPlainText` on
    /// parse failure (in practice never — the Foundation parser is
    /// graceful — but defensive).
    static func render(_ text: String,
                       baseFont: NSFont = .systemFont(ofSize: 13),
                       textColor: NSColor = .labelColor,
                       codeBackgroundColor: NSColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.15)) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            // `.inlineOnlyPreservingWhitespace` is the magic combo: parse
            // *bold*/`code`/[link] inline, but keep newlines and
            // paragraph breaks intact (instead of collapsing them like
            // the default block parser does).
            interpretedSyntax: .inlineOnlyPreservingWhitespace)

        let parsed: AttributedString
        do {
            parsed = try AttributedString(markdown: text, options: options)
        } catch {
            return NSAttributedString(string: text, attributes: [
                .font: baseFont,
                .foregroundColor: textColor,
            ])
        }

        let result = NSMutableAttributedString()
        let bold = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        let italic = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        let codeFont = NSFont.monospacedSystemFont(
            ofSize: baseFont.pointSize - 0.5, weight: .regular)

        for run in parsed.runs {
            let runText = String(parsed[run.range].characters)
            if runText.isEmpty { continue }

            var attrs: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: textColor,
            ]

            let intent = run.inlinePresentationIntent ?? []
            // Intents can stack — `**_both_**` is bold AND italic.
            // Order matters: start from baseFont; if bold, swap; if also
            // italic, layer italic onto the bold; if code, override
            // entirely (monospaced is its own family — italic+bold
            // wouldn't make sense over a coded run).
            if intent.contains(.code) {
                attrs[.font] = codeFont
                attrs[.backgroundColor] = codeBackgroundColor
            } else {
                var font = baseFont
                if intent.contains(.stronglyEmphasized) { font = bold }
                if intent.contains(.emphasized) {
                    font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                    // If neither bold nor italic-on-bold worked, italic
                    // alone is the fall-through.
                    if font == baseFont { font = italic }
                }
                attrs[.font] = font
            }

            // Strikethrough — used in some changelogs for "this is gone now".
            if intent.contains(.strikethrough) {
                attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }

            // Links — clickable when displayed in an NSTextView.
            if let link = run.link {
                attrs[.link] = link
                attrs[.foregroundColor] = NSColor.linkColor
                attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }

            result.append(NSAttributedString(string: runText, attributes: attrs))
        }

        // Paragraph spacing: make multi-paragraph release notes breathe.
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 6
        para.lineSpacing = 1
        result.addAttribute(.paragraphStyle,
                            value: para,
                            range: NSRange(location: 0, length: result.length))

        return result
    }
}
