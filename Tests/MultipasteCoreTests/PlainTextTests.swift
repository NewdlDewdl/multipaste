// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

/// Tests for the pure plain-text-paste policy (`PlainText` / `PasteFlavor`
/// / `PasteWrite`) that backs the v2.4.0 `⇧↩` "paste as plain text" feature.
///
/// The load-bearing guarantee is `pasteWritePlainRtfStripsRtf`: a rich-text
/// item pasted plain must resolve to `.string` (plain only), never
/// `.richText` (which would leak the `.rtf` pasteboard type). Everything
/// else pins the per-kind mapping and the rich-path behavior-preservation.
enum PlainTextTests {

    static func registerAll() {
        TestRegistry.register("PlainText/stringForTextItem", stringForTextItem)
        TestRegistry.register("PlainText/stringForRtfReturnsPlainNotBytes", stringForRtfReturnsPlainNotBytes)
        TestRegistry.register("PlainText/stringForFileURLsReturnsPathText", stringForFileURLsReturnsPathText)
        TestRegistry.register("PlainText/stringForImageIsNil", stringForImageIsNil)
        TestRegistry.register("PlainText/composerAndPlainTextAgree", composerAndPlainTextAgree)
        TestRegistry.register("PlainText/pasteWriteRichTextIsStringOnly", pasteWriteRichTextIsStringOnly)
        TestRegistry.register("PlainText/pasteWritePlainTextIsString", pasteWritePlainTextIsString)
        TestRegistry.register("PlainText/pasteWriteRichRtfIsRichText", pasteWriteRichRtfIsRichText)
        TestRegistry.register("PlainText/pasteWritePlainRtfStripsRtf", pasteWritePlainRtfStripsRtf)
        TestRegistry.register("PlainText/pasteWriteRichFilesIsFileURLs", pasteWriteRichFilesIsFileURLs)
        TestRegistry.register("PlainText/pasteWritePlainFilesIsPathText", pasteWritePlainFilesIsPathText)
        TestRegistry.register("PlainText/pasteWriteRichImageIsImage", pasteWriteRichImageIsImage)
        TestRegistry.register("PlainText/pasteWritePlainImageFallsBackToImage", pasteWritePlainImageFallsBackToImage)
        TestRegistry.register("PlainText/pasteWritePlainEmptyRtfFallsBackToRich", pasteWritePlainEmptyRtfFallsBackToRich)
        TestRegistry.register("PlainText/pasteWritePlainWhitespaceRtfStaysString", pasteWritePlainWhitespaceRtfStaysString)
        TestRegistry.register("PlainText/pasteWritePlainEmptyTextIsEmptyString", pasteWritePlainEmptyTextIsEmptyString)
        TestRegistry.register("PlainText/effectiveFlavorPrefOffNoShiftIsRich", effectiveFlavorPrefOffNoShiftIsRich)
        TestRegistry.register("PlainText/effectiveFlavorPrefOffShiftIsPlain", effectiveFlavorPrefOffShiftIsPlain)
        TestRegistry.register("PlainText/effectiveFlavorPrefOnNoShiftIsPlain", effectiveFlavorPrefOnNoShiftIsPlain)
        TestRegistry.register("PlainText/effectiveFlavorPrefOnShiftIsRich", effectiveFlavorPrefOnShiftIsRich)
        TestRegistry.register("PlainText/hintKeyLegendPrefOffSaysShiftIsPlain", hintKeyLegendPrefOffSaysShiftIsPlain)
        TestRegistry.register("PlainText/hintKeyLegendPrefOnSaysShiftIsRich", hintKeyLegendPrefOnSaysShiftIsRich)
    }

    // MARK: - Fixtures

    private static let rtfBytes = Data("{\\rtf1 styled}".utf8)
    private static func rtfItem(plain: String) -> ClipboardItem {
        ClipboardItem.rtf(rtfData: rtfBytes, plain: plain)
    }
    private static let fileURLs = [
        URL(fileURLWithPath: "/tmp/one.txt"),
        URL(fileURLWithPath: "/tmp/two.txt"),
    ]
    private static let pngBytes = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic

    // MARK: - PlainText.string(for:)

    static func stringForTextItem() throws {
        try expectEqual(PlainText.string(for: .text("hello world")), "hello world")
    }

    static func stringForRtfReturnsPlainNotBytes() throws {
        let plain = "clean unstyled text"
        let s = PlainText.string(for: rtfItem(plain: plain))
        try expectEqual(s, plain)
        try expect(s != String(decoding: rtfBytes, as: UTF8.self),
                   "plain text must be the stored fallback, never the RTF bytes")
    }

    static func stringForFileURLsReturnsPathText() throws {
        let s = PlainText.string(for: .fileURLs(fileURLs))
        try expectEqual(s, PasteboardAugmenter.pathText(forFiles: fileURLs),
                        "a file pasted plain must match the single-copy path text")
    }

    static func stringForImageIsNil() throws {
        let s = PlainText.string(for: .image(pngData: pngBytes, width: 4, height: 4))
        try expect(s == nil, "an image has no plain-text form")
    }

    /// Locks the `MultiPasteComposer.textRepresentation` → `PlainText.string`
    /// refactor: the two must return identical values for every kind so the
    /// multi-paste composer and the plain-text-paste feature can never drift.
    static func composerAndPlainTextAgree() throws {
        let items: [ClipboardItem] = [
            .text("abc"),
            rtfItem(plain: "rich plain"),
            .fileURLs(fileURLs),
            .image(pngData: pngBytes, width: 4, height: 4),
        ]
        for item in items {
            try expectEqual(MultiPasteComposer.textRepresentation(of: item),
                            PlainText.string(for: item),
                            "composer.textRepresentation must equal PlainText.string for \(item.kindLabel)")
        }
    }

    // MARK: - PlainText.pasteWrite(for:flavor:)

    static func pasteWriteRichTextIsStringOnly() throws {
        // Plain text has no richer form, so rich and plain both write .string.
        try expectEqual(PlainText.pasteWrite(for: .text("hi"), flavor: .rich), .string("hi"))
    }

    static func pasteWritePlainTextIsString() throws {
        try expectEqual(PlainText.pasteWrite(for: .text("hi"), flavor: .plainText), .string("hi"))
    }

    static func pasteWriteRichRtfIsRichText() throws {
        let item = rtfItem(plain: "fallback")
        try expectEqual(PlainText.pasteWrite(for: item, flavor: .rich),
                        .richText(rtf: rtfBytes, plain: "fallback"))
    }

    /// THE load-bearing test: pasting a rich-text item plain resolves to a
    /// bare `.string` with the plain fallback; the `.rtf` is gone.
    static func pasteWritePlainRtfStripsRtf() throws {
        let item = rtfItem(plain: "just the words")
        let write = PlainText.pasteWrite(for: item, flavor: .plainText)
        try expectEqual(write, .string("just the words"))
        var isRich = false
        if case .richText = write { isRich = true }
        try expect(!isRich, "plain-text paste of RTF must NOT carry the .rtf type")
    }

    static func pasteWriteRichFilesIsFileURLs() throws {
        try expectEqual(PlainText.pasteWrite(for: .fileURLs(fileURLs), flavor: .rich),
                        .fileURLs(fileURLs))
    }

    static func pasteWritePlainFilesIsPathText() throws {
        try expectEqual(PlainText.pasteWrite(for: .fileURLs(fileURLs), flavor: .plainText),
                        .string(PasteboardAugmenter.pathText(forFiles: fileURLs)))
    }

    static func pasteWriteRichImageIsImage() throws {
        try expectEqual(PlainText.pasteWrite(for: .image(pngData: pngBytes, width: 4, height: 4), flavor: .rich),
                        .image(png: pngBytes))
    }

    /// An image has no plain form, so `⇧↩` on an image falls back to the rich
    /// image write (paste the image) rather than a silent no-op.
    static func pasteWritePlainImageFallsBackToImage() throws {
        try expectEqual(PlainText.pasteWrite(for: .image(pngData: pngBytes, width: 4, height: 4), flavor: .plainText),
                        .image(png: pngBytes))
    }

    /// Regression guard (found in the v2.4.0 adversarial review): an RTF
    /// item whose parsed plain text is EMPTY is capturable; an RTF stub
    /// like `{\rtf1\ansi}` parses to "", and `ClipboardMonitor.snapshot`
    /// only guards emptiness on the plain-text branch. Pasting it plain
    /// used to resolve to `.string("")`, which clears the clipboard and
    /// pastes nothing (a destructive no-op). It must fall back to the rich
    /// write, like an image does.
    static func pasteWritePlainEmptyRtfFallsBackToRich() throws {
        let item = rtfItem(plain: "")
        try expectEqual(PlainText.pasteWrite(for: item, flavor: .plainText),
                        .richText(rtf: rtfBytes, plain: ""),
                        "empty-plain RTF pasted plain must fall back to the rich write, not clobber the clipboard with \"\"")
    }

    /// Guards the guard: the empty-plain fallback must trigger ONLY on
    /// strictly-empty plain text. Whitespace-only plain text (spaces,
    /// newlines) is a legitimate plain paste and stays `.string`.
    static func pasteWritePlainWhitespaceRtfStaysString() throws {
        let item = rtfItem(plain: " \n\t ")
        try expectEqual(PlainText.pasteWrite(for: item, flavor: .plainText),
                        .string(" \n\t "),
                        "whitespace-only plain text is not empty; it must still paste plain")
    }

    /// For a plain-TEXT item the fallback is invisible: the rich write of
    /// `.text("")` is `.string("")` too, so both flavors agree. This pins
    /// that the fallback never changes behavior for text items.
    static func pasteWritePlainEmptyTextIsEmptyString() throws {
        try expectEqual(PlainText.pasteWrite(for: .text(""), flavor: .plainText),
                        PlainText.pasteWrite(for: .text(""), flavor: .rich))
        try expectEqual(PlainText.pasteWrite(for: .text(""), flavor: .plainText), .string(""))
    }

    // MARK: - PasteFlavor.effective(plainTextPasteDefault:shiftPressed:)
    //
    // The full pref × Shift decision table. This used to live untested in
    // AppKit `PickerWindow`; it was extracted here in the v2.4.0 review so
    // every combination is locked. Both the picker and the menu-bar
    // quick-pick forward to this one definition.

    static func effectiveFlavorPrefOffNoShiftIsRich() throws {
        try expectEqual(PasteFlavor.effective(plainTextPasteDefault: false, shiftPressed: false), .rich,
                        "shipped default: bare ↩ pastes rich")
    }

    static func effectiveFlavorPrefOffShiftIsPlain() throws {
        try expectEqual(PasteFlavor.effective(plainTextPasteDefault: false, shiftPressed: true), .plainText,
                        "shipped default: ⇧↩ pastes plain text")
    }

    static func effectiveFlavorPrefOnNoShiftIsPlain() throws {
        try expectEqual(PasteFlavor.effective(plainTextPasteDefault: true, shiftPressed: false), .plainText,
                        "pref on: bare ↩ pastes plain text")
    }

    static func effectiveFlavorPrefOnShiftIsRich() throws {
        try expectEqual(PasteFlavor.effective(plainTextPasteDefault: true, shiftPressed: true), .rich,
                        "pref on: ⇧↩ pastes the rich original")
    }

    // MARK: - PasteFlavor.hintKeyLegend(plainTextPasteDefault:)
    //
    // v2.4.0-review regression guard: the picker's hint bar used to
    // hardcode "⇧↩ plain text", which is the exact OPPOSITE of what ⇧↩
    // does once the pref is on. The legend must always narrate
    // `PasteFlavor.effective` truthfully.

    static func hintKeyLegendPrefOffSaysShiftIsPlain() throws {
        try expectEqual(PasteFlavor.hintKeyLegend(plainTextPasteDefault: false),
                        "↩ paste   ⇧↩ plain text")
    }

    static func hintKeyLegendPrefOnSaysShiftIsRich() throws {
        try expectEqual(PasteFlavor.hintKeyLegend(plainTextPasteDefault: true),
                        "↩ paste plain   ⇧↩ rich",
                        "with the pref on, ⇧↩ pastes RICH; the legend must not claim plain")
    }
}
