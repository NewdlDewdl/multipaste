#!/usr/bin/env swift
// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
//
// Standalone end-to-end smoke test for the plain-text-paste feature
// (⇧↩). Mirrors the decision in `MultipasteCore/PasteFlavor.swift`
// (`PlainText.pasteWrite`) and the executor in `Multipaste/Paster.swift`
// (`Paster.put`), then runs the resulting write against a PRIVATE
// NSPasteboard — so it neither touches nor clobbers the user's real
// clipboard.
//
// Run:
//   swift scripts/plaintext-paste-smoke-test.swift
//
// What it verifies, end-to-end (real AppKit pasteboard APIs, no mocks):
//   1. RICH rtf write declares BOTH .rtf and .string, and both read back.
//   2. PLAIN rtf write declares .string ONLY — the .rtf type is GONE.
//      (This is the load-bearing "paste as plain text strips formatting"
//      guarantee, proven at the NSPasteboard layer where it actually
//      matters, not just in the pure mapping.)
//   3. PLAIN text write yields the string verbatim.
//   4. PLAIN image falls back to the rich image write (.png present),
//      so ⇧↩ on an image still pastes the image rather than nothing.
//
// The pure per-kind mapping itself (which flavor → which PasteWrite) is
// separately unit-tested in Tests/MultipasteCoreTests/PlainTextTests.swift
// against the REAL MultipasteCore code; this script proves the AppKit
// write those decisions drive behaves as claimed on a live pasteboard.
//
// Exit codes: 0 = all passed, 1 = a step failed.

import AppKit
import Foundation

func die(_ message: String, file: String = #file, line: Int = #line) -> Never {
    FileHandle.standardError.write(Data("FAIL [\(file):\(line)] \(message)\n".utf8))
    exit(1)
}
func step(_ label: String) { print("--- \(label)") }
func ok(_ label: String) { print("  ✓ \(label)") }

// ─── mirror of MultipasteCore/PasteFlavor.swift + Multipaste/Paster.swift ───
//
// Re-implemented here because `swift <file>.swift` can't import a package
// module. Kept a faithful copy of the real logic so this integration proof
// matches what ships.

enum Flavor { case rich, plainText }

enum Kind {
    case text(String)
    case rtf(rtf: Data, plain: String)
    case image(png: Data)
    case fileURLs([URL])
}

enum PasteWrite: Equatable {
    case string(String)
    case richText(rtf: Data, plain: String)
    case image(png: Data)
    case fileURLs([URL])
}

func plainString(for kind: Kind) -> String? {
    switch kind {
    case .text(let s): return s
    case .rtf(_, let plain): return plain
    case .fileURLs(let urls): return urls.map(\.path).joined(separator: "\n")
    case .image: return nil
    }
}

func richWrite(for kind: Kind) -> PasteWrite {
    switch kind {
    case .text(let s): return .string(s)
    case .rtf(let rtf, let plain): return .richText(rtf: rtf, plain: plain)
    case .image(let png): return .image(png: png)
    case .fileURLs(let urls): return .fileURLs(urls)
    }
}

func pasteWrite(for kind: Kind, flavor: Flavor) -> PasteWrite {
    switch flavor {
    case .rich:
        return richWrite(for: kind)
    case .plainText:
        if let plain = plainString(for: kind) { return .string(plain) }
        return richWrite(for: kind)
    }
}

/// Exact mirror of `Paster.put`'s executor switch.
func execute(_ write: PasteWrite, to pb: NSPasteboard) {
    pb.clearContents()
    switch write {
    case .string(let s):
        pb.setString(s, forType: .string)
    case .richText(let rtf, let plain):
        pb.declareTypes([.rtf, .string], owner: nil)
        pb.setData(rtf, forType: .rtf)
        pb.setString(plain, forType: .string)
    case .image(let png):
        pb.declareTypes([.png, .tiff], owner: nil)
        pb.setData(png, forType: .png)
    case .fileURLs(let urls):
        pb.writeObjects(urls.map { $0 as NSURL })
    }
}

// ─── the test ─────────────────────────────────────────────────────────

let pb = NSPasteboard(name: NSPasteboard.Name("com.rohin.multipaste.smoke.\(UUID().uuidString)"))
let rtfBytes = try! NSAttributedString(string: "Hello, styled world")
    .data(from: NSRange(location: 0, length: 19),
          documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
let rtfItem = Kind.rtf(rtf: rtfBytes, plain: "Hello, styled world")

step("1. RICH rtf paste declares both .rtf and .string")
execute(pasteWrite(for: rtfItem, flavor: .rich), to: pb)
guard pb.data(forType: .rtf) != nil else { die("rich rtf paste dropped the .rtf type") }
guard pb.string(forType: .string) == "Hello, styled world" else { die("rich rtf paste lost the plain fallback") }
ok("rich rtf → .rtf present AND .string == plain")

step("2. PLAIN rtf paste strips the .rtf type (the load-bearing guarantee)")
execute(pasteWrite(for: rtfItem, flavor: .plainText), to: pb)
if let leaked = pb.data(forType: .rtf) {
    die("plain-text paste LEAKED \(leaked.count) bytes of .rtf — formatting was NOT stripped")
}
guard pb.string(forType: .string) == "Hello, styled world" else { die("plain rtf paste lost the text") }
ok("plain rtf → .rtf ABSENT, .string == plain text")

step("3. PLAIN text paste yields the string verbatim")
execute(pasteWrite(for: .text("just text"), flavor: .plainText), to: pb)
guard pb.string(forType: .string) == "just text" else { die("plain text paste mangled the string") }
guard pb.data(forType: .rtf) == nil else { die("plain text paste somehow carried .rtf") }
ok("plain text → .string == \"just text\"")

step("4. PLAIN image falls back to the rich image write")
let pngMagic = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
execute(pasteWrite(for: .image(png: pngMagic), flavor: .plainText), to: pb)
guard pb.data(forType: .png) == pngMagic else { die("plain image did NOT fall back to pasting the image") }
ok("plain image → falls back to .png (⇧↩ on an image still pastes the image)")

pb.releaseGlobally()
print("\n\u{001B}[32m✓\u{001B}[0m plain-text-paste smoke test passed (4 checks, real NSPasteboard)")
exit(0)
