// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import MultipasteCore

/// Self-check behind the hidden `Multipaste --paste-smoke` flag: runs the
/// REAL `Paster.put` (the shipped executor, not a mirror of it) against a
/// private `NSPasteboard` and verifies every kind x flavor write that
/// matters. `make plaintext-smoke-test` runs this after the standalone
/// script, so the executable target's pasteboard code has direct automated
/// coverage; a mutation to `Paster.put`'s switch fails THIS check even
/// though unit tests never compile the executable target.
///
/// Uses a uniquely-named private pasteboard, so it neither touches nor
/// clobbers the user's clipboard, and exits before `NSApplication` starts
/// (no UI, no single-instance enforcement, no permission prompts).
enum PasteSmokeCheck {

    static func run() -> Int32 {
        let pb = NSPasteboard(name: NSPasteboard.Name(
            "com.rohin.multipaste.paste-smoke.\(UUID().uuidString)"))
        defer { pb.releaseGlobally() }

        var passed = 0
        var failed = 0
        func check(_ label: String, _ ok: Bool) {
            print("  \(ok ? "✓" : "✗") \(label)")
            if ok { passed += 1 } else { failed += 1 }
        }

        let plainText = "Hello, styled world"
        let rtfBytes = try? NSAttributedString(string: plainText)
            .data(from: NSRange(location: 0, length: (plainText as NSString).length),
                  documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        guard let rtfBytes else {
            print("  ✗ could not build RTF fixture")
            return 1
        }
        let rtfItem = ClipboardItem.rtf(rtfData: rtfBytes, plain: plainText)

        Paster.put(rtfItem, flavor: .rich, to: pb)
        check("rich rtf keeps .rtf AND .string",
              pb.data(forType: .rtf) == rtfBytes && pb.string(forType: .string) == plainText)

        Paster.put(rtfItem, flavor: .plainText, to: pb)
        check("plain rtf strips .rtf, keeps the text (the load-bearing guarantee)",
              pb.data(forType: .rtf) == nil && pb.string(forType: .string) == plainText)

        Paster.put(.text("just text"), flavor: .plainText, to: pb)
        check("plain text pastes verbatim, no .rtf",
              pb.string(forType: .string) == "just text" && pb.data(forType: .rtf) == nil)

        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        Paster.put(.image(pngData: png, width: 1, height: 1), flavor: .plainText, to: pb)
        check("plain image falls back to the rich .png write",
              pb.data(forType: .png) == png)

        let emptyStub = Data("{\\rtf1\\ansi}".utf8)
        Paster.put(.rtf(rtfData: emptyStub, plain: ""), flavor: .plainText, to: pb)
        check("plain empty-rtf falls back to the rich .rtf write (no clipboard clobber)",
              pb.data(forType: .rtf) == emptyStub)

        let urls = [URL(fileURLWithPath: "/tmp/one.txt"), URL(fileURLWithPath: "/tmp/two.txt")]
        Paster.put(.fileURLs(urls), flavor: .plainText, to: pb)
        check("plain files paste newline-joined path text",
              pb.string(forType: .string) == PasteboardAugmenter.pathText(forFiles: urls))

        Paster.put(.fileURLs(urls), flavor: .rich, to: pb)
        let readBack = pb.readObjects(forClasses: [NSURL.self],
                                      options: [.urlReadingFileURLsOnly: true]) as? [URL]
        check("rich files write real file URLs",
              readBack == urls)

        if failed == 0 {
            print("\u{001B}[32m✓\u{001B}[0m paste-smoke: \(passed) checks passed (real Paster.put, private NSPasteboard)")
            return 0
        }
        print("\u{001B}[31m✗\u{001B}[0m paste-smoke: \(failed) of \(passed + failed) checks FAILED")
        return 1
    }
}
