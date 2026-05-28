#!/usr/bin/env swift
// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
//
// Visual preview of the "Multipaste vX.Y.Z is available" update
// dialog. Shows the dialog NOW on the user's screen with the SAME
// release-notes markdown that produced the screenshot Rohin reported
// (the v2.0.2 dialog rendering literal `##`, `**`, ```` ` ````, and
// `>` instead of formatted text).
//
// Run:   swift scripts/preview-update-dialog.swift
// Or:    make preview-update-dialog
//
// What you should see:
//   - "Hotfix" rendered as plain text (not "**Hotfix:**")
//   - "in-DMG `READ ME FIRST.txt`" with the filename in monospaced font
//     with a subtle gray background — NOT surrounded by literal
//     backticks
//   - "ad-hoc-signed" / other emphasized words in bold
//   - NO `##`, `**`, ```` ` ````, or `[Cancel]` literal sigils anywhere
//   - The summary stops cleanly at the bug-description paragraph; the
//     "### The bug" subsection with blockquote etc. does NOT appear
//
// This script re-implements the formatter + renderer inline (a small
// mirror of `Sources/MultipasteCore/ReleaseNotesFormatter.swift` +
// `Sources/Multipaste/MarkdownAttributedString.swift`) because
// `swift <file>.swift` can't easily import SwiftPM targets. The
// canonical implementation is verified by 20+ unit tests in the test
// target.

import AppKit
import Foundation

// ─── inline mirror of ReleaseNotesFormatter.summary ─────────────────

func summary(from notes: String) -> String {
    var lines = notes.components(separatedBy: "\n")
    if let first = lines.first, first.hasPrefix("## ") {
        lines.removeFirst()
        while let next = lines.first, next.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeFirst()
        }
    }
    var out: [String] = []
    for line in lines {
        if line.hasPrefix("### ") { break }
        if line.hasPrefix("## ")  { break }
        out.append(line)
    }
    return out.joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

// ─── inline mirror of MarkdownAttributedString.render ───────────────

func renderMarkdown(_ text: String) -> NSAttributedString {
    let baseFont = NSFont.systemFont(ofSize: 13)
    let bold = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
    let italic = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
    let codeFont = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
    let codeBG = NSColor.tertiaryLabelColor.withAlphaComponent(0.15)

    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace)
    let parsed = (try? AttributedString(markdown: text, options: options))
        ?? AttributedString(text)

    let result = NSMutableAttributedString()
    for run in parsed.runs {
        let runText = String(parsed[run.range].characters)
        var attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
        ]
        let intent = run.inlinePresentationIntent ?? []
        if intent.contains(.code) {
            attrs[.font] = codeFont
            attrs[.backgroundColor] = codeBG
        } else {
            var font = baseFont
            if intent.contains(.stronglyEmphasized) { font = bold }
            if intent.contains(.emphasized) {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                if font == baseFont { font = italic }
            }
            attrs[.font] = font
        }
        result.append(NSAttributedString(string: runText, attributes: attrs))
    }
    let para = NSMutableParagraphStyle()
    para.paragraphSpacing = 6
    para.lineSpacing = 1
    result.addAttribute(.paragraphStyle, value: para,
                        range: NSRange(location: 0, length: result.length))
    return result
}

// ─── the actual v2.0.2 CHANGELOG entry that produced the bug ───────

let releaseNotesV202 = """
## 2.0.2 — 2026-05-16

Hotfix: the **in-DMG `READ ME FIRST.txt`** told users to double-click Multipaste on first launch — which doesn't work for an ad-hoc-signed app downloaded from the internet.

### The bug

Multipaste is ad-hoc signed (no Apple Developer ID — we'd need a $99/yr Apple Developer Program membership for that). Apps without Developer ID signing trigger Gatekeeper on first launch.
"""

// ─── build and show the dialog ──────────────────────────────────────

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let extracted = summary(from: releaseNotesV202)
let rendered = renderMarkdown(extracted)

print("---")
print("Summary extracted (plain text view):")
print(extracted)
print("---")

let alert = NSAlert()
alert.messageText = "Multipaste 2.1.0 is available."
alert.informativeText = "You're running 2.0.2. Here's what's new:"

// Build the same scrolling text-view accessory the production
// UpdateService now uses.
let tv = NSTextView()
tv.isEditable = false
tv.isSelectable = true
tv.drawsBackground = false
tv.textContainerInset = NSSize(width: 4, height: 6)
tv.textStorage?.setAttributedString(rendered)
tv.frame = NSRect(x: 0, y: 0, width: 520, height: 1000)
tv.textContainer?.containerSize = NSSize(width: 512, height: CGFloat.greatestFiniteMagnitude)
tv.layoutManager?.ensureLayout(for: tv.textContainer!)
let natural = tv.layoutManager?.usedRect(for: tv.textContainer!).height ?? 100
let h = max(60, min(240, natural + 14))

let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: h))
scroll.hasVerticalScroller = (natural + 14 > h)
scroll.hasHorizontalScroller = false
scroll.borderType = .bezelBorder
scroll.autohidesScrollers = true
scroll.drawsBackground = true
scroll.backgroundColor = .textBackgroundColor
scroll.documentView = tv
alert.accessoryView = scroll

alert.addButton(withTitle: "Looks good")
alert.addButton(withTitle: "Looks broken")

// If MULTIPASTE_PREVIEW_AUTOSHOT=path is set, take a screenshot of
// the dialog as soon as it's shown and exit. Otherwise wait for the
// user to click a button.
if let outPath = ProcessInfo.processInfo.environment["MULTIPASTE_PREVIEW_AUTOSHOT"] {
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800)) {
        // Capture the dialog window. We don't know the window ID a
        // priori, so we shell out to /usr/sbin/screencapture which
        // grabs the whole screen — that's fine, the dialog is the
        // frontmost element and dominates the captured image.
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "-o", outPath]
        do {
            try task.run()
            task.waitUntilExit()
            print("✓ screenshot saved: \(outPath)")
        } catch {
            print("✗ screencapture failed: \(error)")
        }
        // Dismiss the alert by ending modal — same as clicking the
        // first button programmatically.
        NSApp.abortModal()
        DispatchQueue.main.async { exit(0) }
    }
}

app.activate(ignoringOtherApps: true)
let response = alert.runModal()
print(response == .alertFirstButtonReturn ? "✓ user confirmed dialog renders correctly" : "✗ user reported broken dialog")
exit(response == .alertFirstButtonReturn ? 0 : 1)
