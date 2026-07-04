// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

// Locks in the multi-paste decision table:
//   nothing → nil; one item → .single; all files → .combined fileURLs;
//   all text-representable → .combined text (separator-joined, mark
//   order); image in the mix → .sequential (mark order).

enum MultiPasteComposerTests {

    static func registerAll() {
        TestRegistry.register("MultiPasteComposer/emptyPickPlansNothing", emptyPickPlansNothing)
        TestRegistry.register("MultiPasteComposer/singleItemUsesClassicSinglePath", singleItemUsesClassicSinglePath)
        TestRegistry.register("MultiPasteComposer/singleImageStaysSingleNotSequential", singleImageStaysSingleNotSequential)
        TestRegistry.register("MultiPasteComposer/textsCombineWithSeparatorInMarkOrder", textsCombineWithSeparatorInMarkOrder)
        TestRegistry.register("MultiPasteComposer/blankLineSpaceTabAndEmptySeparatorsWork", blankLineSpaceTabAndEmptySeparatorsWork)
        TestRegistry.register("MultiPasteComposer/rtfContributesItsPlainText", rtfContributesItsPlainText)
        TestRegistry.register("MultiPasteComposer/allFilesMergeIntoOneMultiFilePaste", allFilesMergeIntoOneMultiFilePaste)
        TestRegistry.register("MultiPasteComposer/mergedFilesDedupeKeepingFirstOccurrence", mergedFilesDedupeKeepingFirstOccurrence)
        TestRegistry.register("MultiPasteComposer/textPlusFilesCombinesUsingPaths", textPlusFilesCombinesUsingPaths)
        TestRegistry.register("MultiPasteComposer/imageInMixForcesSequential", imageInMixForcesSequential)
        TestRegistry.register("MultiPasteComposer/twoImagesGoSequentialInMarkOrder", twoImagesGoSequentialInMarkOrder)
        TestRegistry.register("MultiPasteComposer/sequentialPreservesExactItems", sequentialPreservesExactItems)
        TestRegistry.register("MultiPasteComposer/combinedTextItemHasUsablePreview", combinedTextItemHasUsablePreview)
        TestRegistry.register("MultiPasteComposer/textRepresentationPerKind", textRepresentationPerKind)
        TestRegistry.register("MultiPasteComposer/interItemDelayIsHumanImperceptibleButSafe", interItemDelayIsHumanImperceptibleButSafe)
        TestRegistry.register("MultiPasteComposer/allFilesPlainTextJoinsPathsWithSeparator", allFilesPlainTextJoinsPathsWithSeparator)
        TestRegistry.register("MultiPasteComposer/allFilesRichStaysOneMultiFilePaste", allFilesRichStaysOneMultiFilePaste)
        TestRegistry.register("MultiPasteComposer/planWithoutFlavorDefaultsToRich", planWithoutFlavorDefaultsToRich)
    }

    // MARK: - Fixtures

    private static func png(_ byte: UInt8) -> ClipboardItem {
        .image(pngData: Data([byte, 1, 2, 3]), width: 4, height: 4)
    }

    private static func files(_ paths: [String]) -> ClipboardItem {
        .fileURLs(paths.map { URL(fileURLWithPath: $0) })
    }

    // MARK: - Empty / single

    static func emptyPickPlansNothing() throws {
        try expectEqual(MultiPasteComposer.plan(items: [], separator: "\n"), nil)
    }

    static func singleItemUsesClassicSinglePath() throws {
        let item = ClipboardItem.text("hello")
        guard case .single(let planned)? = MultiPasteComposer.plan(items: [item], separator: "\n") else {
            throw TestFailure(message: "one item must plan .single", file: #file, line: #line)
        }
        try expectEqual(planned.id, item.id, "single path must paste the EXACT item picked, not a copy")
    }

    static func singleImageStaysSingleNotSequential() throws {
        let img = png(9)
        guard case .single? = MultiPasteComposer.plan(items: [img], separator: "\n") else {
            throw TestFailure(message: "a lone image is a normal single paste", file: #file, line: #line)
        }
    }

    // MARK: - Combined text

    static func textsCombineWithSeparatorInMarkOrder() throws {
        let a = ClipboardItem.text("first")
        let b = ClipboardItem.text("second")
        let c = ClipboardItem.text("third")
        guard case .combined(let item)? = MultiPasteComposer.plan(items: [c, a, b], separator: "\n") else {
            throw TestFailure(message: "all-text picks must combine", file: #file, line: #line)
        }
        guard case .text(let joined) = item.kind else {
            throw TestFailure(message: "combined text plan must produce a .text item", file: #file, line: #line)
        }
        try expectEqual(joined, "third\nfirst\nsecond",
                        "combined order is MARK order (c, a, b), not creation order")
    }

    static func blankLineSpaceTabAndEmptySeparatorsWork() throws {
        let a = ClipboardItem.text("x")
        let b = ClipboardItem.text("y")
        for (sep, expected) in [("\n\n", "x\n\ny"), (" ", "x y"), ("\t", "x\ty"), ("", "xy")] {
            guard case .combined(let item)? = MultiPasteComposer.plan(items: [a, b], separator: sep),
                  case .text(let joined) = item.kind else {
                throw TestFailure(message: "separator \(sep.debugDescription) must still combine",
                                  file: #file, line: #line)
            }
            try expectEqual(joined, expected, "separator \(sep.debugDescription)")
        }
    }

    static func rtfContributesItsPlainText() throws {
        let rich = ClipboardItem.rtf(rtfData: Data([0x7B]), plain: "bold words")
        let plain = ClipboardItem.text("intro")
        guard case .combined(let item)? = MultiPasteComposer.plan(items: [plain, rich], separator: "\n"),
              case .text(let joined) = item.kind else {
            throw TestFailure(message: "text+rtf must combine as text", file: #file, line: #line)
        }
        try expectEqual(joined, "intro\nbold words",
                        "RTF items contribute their plain-text form to a combined paste")
    }

    // MARK: - Combined files

    static func allFilesMergeIntoOneMultiFilePaste() throws {
        let one = files(["/tmp/a.txt", "/tmp/b.txt"])
        let two = files(["/tmp/c.txt"])
        guard case .combined(let item)? = MultiPasteComposer.plan(items: [one, two], separator: "\n"),
              case .fileURLs(let urls) = item.kind else {
            throw TestFailure(message: "all-file picks must merge into one multi-file pasteboard",
                              file: #file, line: #line)
        }
        try expectEqual(urls.map(\.path), ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"],
                        "merged file list preserves mark order")
    }

    static func mergedFilesDedupeKeepingFirstOccurrence() throws {
        let one = files(["/tmp/a.txt", "/tmp/b.txt"])
        let two = files(["/tmp/b.txt", "/tmp/c.txt"])
        guard case .combined(let item)? = MultiPasteComposer.plan(items: [one, two], separator: "\n"),
              case .fileURLs(let urls) = item.kind else {
            throw TestFailure(message: "expected combined fileURLs", file: #file, line: #line)
        }
        try expectEqual(urls.map(\.path), ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"],
                        "pasting the same file twice in one operation is meaningless; dedupe, keep first slot")
    }

    /// v2.4.0-review regression guard: an all-file pick pasted PLAIN must
    /// honor the user's multi-paste separator, exactly like two marked text
    /// items would under the same `⇧↩` gesture. (Pasted rich, it stays a
    /// multi-file pasteboard; see `allFilesRichStaysOneMultiFilePaste`.)
    static func allFilesPlainTextJoinsPathsWithSeparator() throws {
        let one = files(["/tmp/a.txt"])
        let two = files(["/tmp/b.txt"])
        guard case .combined(let item)? = MultiPasteComposer.plan(items: [one, two], separator: ", ",
                                                                  flavor: .plainText),
              case .text(let joined) = item.kind else {
            throw TestFailure(message: "all-file pick pasted plain must combine as separator-joined text",
                              file: #file, line: #line)
        }
        try expectEqual(joined, "/tmp/a.txt, /tmp/b.txt",
                        "plain multi-file paste honors the user's separator")
    }

    /// Guards the guard: the plain-text routing must not leak into the rich
    /// path. Rich all-file picks keep the one-multi-file-pasteboard plan.
    static func allFilesRichStaysOneMultiFilePaste() throws {
        let one = files(["/tmp/a.txt"])
        let two = files(["/tmp/b.txt"])
        guard case .combined(let item)? = MultiPasteComposer.plan(items: [one, two], separator: ", ",
                                                                  flavor: .rich),
              case .fileURLs(let urls) = item.kind else {
            throw TestFailure(message: "rich all-file pick must stay a multi-file pasteboard",
                              file: #file, line: #line)
        }
        try expectEqual(urls.map(\.path), ["/tmp/a.txt", "/tmp/b.txt"])
    }

    /// Backward-compat pin: `plan` without a flavor argument behaves exactly
    /// like the pre-flavor API (rich), so no existing caller changes meaning.
    static func planWithoutFlavorDefaultsToRich() throws {
        let one = files(["/tmp/a.txt"])
        let two = files(["/tmp/b.txt"])
        guard case .combined(let item)? = MultiPasteComposer.plan(items: [one, two], separator: ", "),
              case .fileURLs = item.kind else {
            throw TestFailure(message: "flavor-less plan() must default to the rich multi-file behavior",
                              file: #file, line: #line)
        }
    }

    static func textPlusFilesCombinesUsingPaths() throws {
        let note = ClipboardItem.text("see these:")
        let attachments = files(["/tmp/a.txt", "/tmp/b.txt"])
        guard case .combined(let item)? = MultiPasteComposer.plan(items: [note, attachments], separator: "\n"),
              case .text(let joined) = item.kind else {
            throw TestFailure(message: "text+files must combine as text", file: #file, line: #line)
        }
        try expectEqual(joined, "see these:\n/tmp/a.txt\n/tmp/b.txt",
                        "file items in a text combine render as their paths (same as PasteboardAugmenter)")
    }

    // MARK: - Sequential

    static func imageInMixForcesSequential() throws {
        let caption = ClipboardItem.text("screenshot:")
        let shot = png(7)
        guard case .sequential(let seq)? = MultiPasteComposer.plan(items: [caption, shot], separator: "\n") else {
            throw TestFailure(message: "an image cannot concatenate; must go sequential",
                              file: #file, line: #line)
        }
        try expectEqual(seq.map(\.id), [caption.id, shot.id], "sequential keeps mark order")
    }

    static func twoImagesGoSequentialInMarkOrder() throws {
        let first = png(1)
        let second = png(2)
        guard case .sequential(let seq)? = MultiPasteComposer.plan(items: [second, first], separator: "\n") else {
            throw TestFailure(message: "two images must paste one after another", file: #file, line: #line)
        }
        try expectEqual(seq.map(\.id), [second.id, first.id])
    }

    static func sequentialPreservesExactItems() throws {
        let a = png(1)
        let b = ClipboardItem.text("t")
        let c = png(2)
        guard case .sequential(let seq)? = MultiPasteComposer.plan(items: [a, b, c], separator: "\n") else {
            throw TestFailure(message: "expected sequential", file: #file, line: #line)
        }
        try expectEqual(seq.count, 3)
        try expectEqual(seq.map(\.id), [a.id, b.id, c.id],
                        "sequential delivery pastes the exact picked items, nothing merged or dropped")
    }

    // MARK: - Combined item hygiene

    static func combinedTextItemHasUsablePreview() throws {
        let a = ClipboardItem.text("alpha")
        let b = ClipboardItem.text("beta")
        guard case .combined(let item)? = MultiPasteComposer.plan(items: [a, b], separator: "\n") else {
            throw TestFailure(message: "expected combined", file: #file, line: #line)
        }
        // The combined item flows into history via the clipboard monitor;
        // it must look like any other text item (preview, label, hash).
        try expect(item.preview.contains("alpha"), "combined item needs a real preview")
        try expectEqual(item.kindLabel, "Text")
        try expect(item.contentHash.hasPrefix("text:"))
        try expectNotEqual(item.id, a.id, "combined item is a NEW item, not a mutation of a picked one")
    }

    static func textRepresentationPerKind() throws {
        try expectEqual(MultiPasteComposer.textRepresentation(of: .text("plain")), "plain")
        try expectEqual(MultiPasteComposer.textRepresentation(
            of: .rtf(rtfData: Data(), plain: "rich-as-plain")), "rich-as-plain")
        try expectEqual(MultiPasteComposer.textRepresentation(of: files(["/a", "/b"])), "/a\n/b")
        try expectEqual(MultiPasteComposer.textRepresentation(of: png(0)), nil,
                        "images have no text form; this is what forces sequential plans")
    }

    /// The inter-item delay is a timing contract, not a tunable: long
    /// enough that the target app has read the pasteboard for paste N
    /// before we overwrite it with item N+1, short enough that a 5-item
    /// paste completes in under a second. Lock the window so a future
    /// "optimization" can't silently reintroduce the swap race.
    static func interItemDelayIsHumanImperceptibleButSafe() throws {
        try expect(MultiPasteComposer.sequentialInterItemDelay >= 0.1,
                   "below ~100ms the pasteboard swap can outrun the target app's paste handling")
        try expect(MultiPasteComposer.sequentialInterItemDelay <= 0.3,
                   "above ~300ms a multi-item paste feels broken/laggy")
    }
}
