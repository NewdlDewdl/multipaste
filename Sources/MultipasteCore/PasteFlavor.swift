// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Which representation of an item to put on the pasteboard when the user
/// pastes it.
///
/// - `.rich`: the item's richest form, RTF for rich text, PNG for images,
///   file URLs for file copies, plain string for plain text. This is the
///   historical (and default) behavior.
/// - `.plainText`: strip all formatting and paste the unstyled string. A
///   styled clip from a webpage / Word / Notion arrives as clean text with
///   no fonts, colors, or sizes. Bound to `⇧↩` in the picker.
///
/// The picker computes the effective flavor per pick (`⇧` inverts the
/// user's `plainTextPasteDefault` preference); the app layer just executes
/// whatever `PlainText.pasteWrite(for:flavor:)` decides.
public enum PasteFlavor: Sendable, Equatable {
    case rich
    case plainText

    /// The flavor a pick should use, resolved from the user's
    /// `plainTextPasteDefault` preference and whether `⇧` is held.
    ///
    /// The base is the preference (`false` → `.rich`, `true` → `.plainText`);
    /// Shift inverts it. So with the shipped default (pref off), `↩` pastes
    /// rich and `⇧↩` pastes plain text; with the pref on, `↩` pastes plain
    /// and `⇧↩` pastes the rich original. Symmetric either way; the other
    /// flavor is always exactly one `⇧` away.
    ///
    /// Lives here (not in the picker) so the decision is pure and
    /// unit-tested; `PickerWindow` and the menu-bar quick-pick both forward
    /// to this one definition.
    public static func effective(plainTextPasteDefault: Bool, shiftPressed: Bool) -> PasteFlavor {
        let base: PasteFlavor = plainTextPasteDefault ? .plainText : .rich
        guard shiftPressed else { return base }
        return base == .plainText ? .rich : .plainText
    }
}

/// A fully-resolved description of what to write onto the pasteboard for a
/// single item, in the chosen `PasteFlavor`.
///
/// This exists so the *decision* (which pasteboard types get declared and
/// what bytes they carry) is pure, `AppKit`-free, and unit-testable. The
/// app layer's `Paster` is then a thin executor that maps each case to the
/// matching `NSPasteboard` calls, with no policy of its own. In particular,
/// the load-bearing "paste as plain text strips the RTF" guarantee is
/// provable here: a rich-text item in `.plainText` resolves to `.string`
/// (plain only), never `.richText` (which would leak the `.rtf` type).
public enum PasteWrite: Equatable {
    /// Declare `.string` only and write this text. No `.rtf`, no rich types.
    case string(String)
    /// Declare `.rtf` + `.string`; write the RTF bytes and the plain fallback.
    case richText(rtf: Data, plain: String)
    /// Declare `.png` (+ `.tiff` fallback at the app layer); write PNG bytes.
    case image(png: Data)
    /// Write these file URLs as pasteboard objects (a real file copy).
    case fileURLs([URL])
}

/// Pure policy for plain-text paste.
///
/// Kept `AppKit`-free (mirrors `MultiPasteComposer` / `PasteRouting` /
/// `TabNavigation`) so every rule is unit-tested.
public enum PlainText {

    /// The unstyled string stand-in for an item, or `nil` if it has none
    /// (images). This is the single source of truth for "what is the plain
    /// text of this item"; `MultiPasteComposer.textRepresentation` forwards
    /// here so the two can never drift.
    ///
    /// - `.text`     → the string verbatim.
    /// - `.rtf`      → the stored plain fallback (NOT the RTF bytes).
    /// - `.fileURLs` → the full paths, one per line, exactly the text
    ///   `PasteboardAugmenter` already injects for a single file copy, so a
    ///   file pasted as plain text matches pasting it into a code editor.
    /// - `.image`    → `nil` (an image has no plain-text form).
    public static func string(for item: ClipboardItem) -> String? {
        switch item.kind {
        case .text(let s):
            return s
        case .rtf(_, let plain):
            return plain
        case .fileURLs(let urls):
            return PasteboardAugmenter.pathText(forFiles: urls)
        case .image:
            return nil
        }
    }

    /// Resolve what to actually put on the pasteboard for `item` in `flavor`.
    ///
    /// `.rich` reproduces the historical per-kind write exactly (rich text →
    /// `.richText`, image → `.image`, files → `.fileURLs`, text → `.string`).
    ///
    /// `.plainText` collapses every text-bearing kind to `.string` (plain):
    /// rich text drops its `.rtf`, a file copy becomes its path text. An
    /// image has no plain form, so `.plainText` on an image falls back to the
    /// rich `.image` write; a `⇧↩` on an image still pastes the image rather
    /// than silently pasting nothing. The same fallback applies when the
    /// plain form is EMPTY: an RTF item whose parsed text is "" is capturable
    /// (`ClipboardMonitor` only guards emptiness for plain-text captures), and
    /// writing `.string("")` would clobber the clipboard with nothing and
    /// paste nothing. Whitespace-only plain text is NOT empty; pasting
    /// spaces or newlines plain is legitimate and stays `.string`.
    public static func pasteWrite(for item: ClipboardItem, flavor: PasteFlavor) -> PasteWrite {
        switch flavor {
        case .rich:
            return richWrite(for: item)
        case .plainText:
            if let plain = string(for: item), !plain.isEmpty {
                return .string(plain)
            }
            // No plain-text form (image), or an empty one (empty-plain RTF):
            // fall back to the rich write so the paste isn't a destructive
            // no-op. (For `.text("")` the rich write is `.string("")` anyway,
            // so this changes nothing for plain-text items.)
            return richWrite(for: item)
        }
    }

    /// The item's richest pasteboard write. Matches the pre-v2.4.0 behavior
    /// of `Paster.put` one-for-one.
    private static func richWrite(for item: ClipboardItem) -> PasteWrite {
        switch item.kind {
        case .text(let s):
            return .string(s)
        case .rtf(let rtf, let plain):
            return .richText(rtf: rtf, plain: plain)
        case .image(let png, _, _):
            return .image(png: png)
        case .fileURLs(let urls):
            return .fileURLs(urls)
        }
    }
}
