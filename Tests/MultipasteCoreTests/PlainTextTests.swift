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
    /// bare `.string` with the plain fallback — the `.rtf` is gone.
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
}
