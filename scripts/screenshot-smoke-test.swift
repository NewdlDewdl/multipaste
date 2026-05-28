#!/usr/bin/env swift
// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0
//
// Standalone end-to-end smoke test for the screenshot-to-clipboard
// pipeline. Mirrors `Sources/Multipaste/ScreenshotWatcher.swift` but
// runs in isolation against a temp directory and a private
// NSPasteboard — so it neither touches the user's real screenshot
// directory NOR clobbers the user's real clipboard.
//
// Run:
//   swift scripts/screenshot-smoke-test.swift
//
// What it verifies, end-to-end (real APIs, no mocks):
//   1. `DispatchSource.makeFileSystemObjectSource` fires on a
//      directory's mtime change.
//   2. The pure `ScreenshotDetector` filename match logic agrees with
//      a synthetic "Screenshot YYYY-MM-DD at H.MM.SS AM.png" file.
//   3. An `NSImage` round-trips PNG → TIFF representations.
//   4. `NSPasteboard.declareTypes` + `setData` on a private pasteboard
//      yields readable image data back.
//
// Exit codes: 0 = all passed, 1 = a step failed.

import AppKit
import Foundation

// ─── helpers ─────────────────────────────────────────────────────────

func die(_ message: String, file: String = #file, line: Int = #line) -> Never {
    FileHandle.standardError.write(Data("FAIL [\(file):\(line)] \(message)\n".utf8))
    exit(1)
}

func step(_ label: String) {
    print("--- \(label)")
}

func ok(_ label: String) {
    print("  ✓ \(label)")
}

// ─── mirror of MultipasteCore/ScreenshotDetector.swift ───────────────
//
// Re-implemented here because `swift <file>.swift` can't import a
// SwiftPM library target without ceremony. Keeping these in sync is
// audited by `Tests/MultipasteCoreTests/ScreenshotDetectorTests.swift`
// — the 32 unit tests there exercise the canonical implementation.

let recognizedExtensions: Set<String> = [
    "png", "jpg", "jpeg", "tiff", "tif", "heic", "pdf",
]

func isLikelyScreenshot(filename: String, prefix: String = "Screenshot") -> Bool {
    guard !filename.isEmpty, !prefix.isEmpty, !filename.hasPrefix(".") else { return false }
    let ext = (filename as NSString).pathExtension.lowercased()
    guard recognizedExtensions.contains(ext) else { return false }
    let stem = (filename as NSString).deletingPathExtension
    return stem == prefix
        || stem.hasPrefix(prefix + " ")
        || stem.hasPrefix(prefix + "_")
}

// ─── 1. Synthesize a tiny PNG ────────────────────────────────────────

step("synthesizing a 64×64 red PNG (representative of a real screenshot)")
let img = NSImage(size: NSSize(width: 64, height: 64))
img.lockFocus()
NSColor.systemRed.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 64, height: 64)).fill()
img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    die("Could not encode the synthetic image to PNG")
}
ok("PNG encoded (\(png.count) bytes)")

// ─── 2. Set up the temp watch directory ──────────────────────────────

step("creating a temp watch directory")
let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    .appendingPathComponent("multipaste-screenshot-smoke-\(UUID().uuidString)",
                           isDirectory: true)
try? FileManager.default.removeItem(at: tempRoot)
try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tempRoot) }
ok("temp dir: \(tempRoot.path)")

// ─── 3. Attach a DispatchSourceFileSystemObject watcher ─────────────

step("attaching DispatchSourceFileSystemObject watcher")
let fd = open(tempRoot.path, O_EVTONLY)
guard fd >= 0 else { die("open(\(tempRoot.path), O_EVTONLY) failed: errno=\(errno)") }
defer { close(fd) }

let scanQueue = DispatchQueue(label: "smoke-test.scan")
let src = DispatchSource.makeFileSystemObjectSource(
    fileDescriptor: fd,
    eventMask: [.write, .extend, .rename, .link],
    queue: scanQueue)

let fired = DispatchSemaphore(value: 0)
var fireCount = 0
src.setEventHandler {
    fireCount += 1
    fired.signal()
}
src.resume()
defer { src.cancel() }
ok("watcher attached on fd \(fd)")

// ─── 4. Drop a fake screenshot in the watch dir ──────────────────────

step("dropping Screenshot 2026-05-28 at 10.13.42 AM.png into the watch dir")
let screenshotURL = tempRoot
    .appendingPathComponent("Screenshot 2026-05-28 at 10.13.42 AM.png")
try png.write(to: screenshotURL)
ok("file written (\(png.count) bytes)")

// Confirm the pure-logic detector recognizes the filename. Belt-and-
// suspenders against the canonical implementation drifting from this
// mirror (the unit tests are the canonical guard; this is a runtime
// belt).
guard isLikelyScreenshot(filename: screenshotURL.lastPathComponent) else {
    die("detector REJECTS a default-format screenshot filename")
}
ok("detector recognizes filename")

// ─── 5. Wait for the watcher to fire ─────────────────────────────────

step("waiting up to 2 seconds for the DispatchSource to fire")
let result = fired.wait(timeout: .now() + .seconds(2))
guard result == .success else {
    die("DispatchSource never fired — either DispatchSourceFileSystemObject is broken on this Mac OR the temp dir's volume doesn't support kqueue events (network/synthetic FS?)")
}
ok("fired \(fireCount) time(s)")

// ─── 6. Replay the screenshot-watcher's diff-and-publish pipeline ──

step("listing the watch dir, finding NEW screenshot files")
let names = try FileManager.default.contentsOfDirectory(atPath: tempRoot.path)
let screenshots = names.filter { isLikelyScreenshot(filename: $0) }
guard screenshots.count == 1 else {
    die("expected exactly 1 screenshot in dir, found \(screenshots.count): \(names)")
}
ok("found 1 screenshot: \(screenshots[0])")

// ─── 7. Read it back ─────────────────────────────────────────────────

step("reading the screenshot bytes back from disk")
let readBack = try Data(contentsOf: screenshotURL)
guard readBack == png else {
    die("read-back PNG (\(readBack.count) bytes) != written PNG (\(png.count) bytes)")
}
ok("read-back PNG matches byte-for-byte")

// ─── 8. Write to a PRIVATE pasteboard, read back ─────────────────────
//
// `NSPasteboard.general` is the system-wide one — clobbering it would
// be rude. `NSPasteboard(name:)` with a unique name is a per-app
// pasteboard, perfect for testing.

step("writing image data to a PRIVATE NSPasteboard, reading back")
let pbName = NSPasteboard.Name("com.rohin.multipaste.smoke-\(UUID().uuidString)")
let pb = NSPasteboard(name: pbName)
defer { pb.clearContents() }

guard let imgFromDisk = NSImage(data: readBack),
      let tiffFromImg = imgFromDisk.tiffRepresentation else {
    die("NSImage(data:) failed to round-trip the read-back PNG")
}

pb.clearContents()
pb.declareTypes([.png, .tiff], owner: nil)
pb.setData(readBack, forType: .png)
pb.setData(tiffFromImg, forType: .tiff)

guard let pngOut = pb.data(forType: .png) else {
    die("private pasteboard returned nil for .png after declareTypes + setData")
}
guard pngOut == readBack else {
    die("private pasteboard returned mismatched PNG bytes (\(pngOut.count) vs \(readBack.count))")
}
ok("private pasteboard round-tripped PNG (\(pngOut.count) bytes)")

guard pb.data(forType: .tiff) != nil else {
    die("private pasteboard returned nil for .tiff after declareTypes + setData")
}
ok("private pasteboard has .tiff representation")

// ─── 9. Negative case: pasteboard doesn't accept random formats ─────

step("negative: confirming declareTypes is exclusive")
guard pb.data(forType: NSPasteboard.PasteboardType("public.url-fragment")) == nil else {
    die("private pasteboard returned data for an undeclared type — wrong type filtering")
}
ok("undeclared type returns nil")

// ─── done ────────────────────────────────────────────────────────────

print("")
print("✓ screenshot-smoke-test passed — the pipeline works end-to-end on this Mac.")
exit(0)
