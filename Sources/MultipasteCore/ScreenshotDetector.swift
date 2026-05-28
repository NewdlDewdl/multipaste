// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Pure helpers for the "auto-copy screenshots to clipboard" feature.
///
/// macOS's `screencapture` command (driven by ⌘⇧3, ⌘⇧4, ⌘⇧5) saves to
/// disk by default — typically `~/Desktop` — and only copies to the
/// clipboard when the user remembers to hold `Control` (⌃⌘⇧4 etc.).
/// Most people never remember. This feature watches the screenshot save
/// location and auto-copies new screenshots to the clipboard, so they
/// land in Multipaste's history alongside every other ⌘C.
///
/// All decisions about WHERE the screenshot lives and WHAT counts as a
/// screenshot live here so the watcher in the AppKit target is a thin
/// wrapper over file-system events.
public enum ScreenshotDetector {

    /// Image extensions that macOS's `screencapture` can write. PNG is the
    /// default and by far the most common; the others appear when the
    /// user has run `defaults write com.apple.screencapture type jpg`
    /// (or `tiff` / `heic` etc.).
    ///
    /// Stored as a static array (not a `Set<String>`) so the lookup is
    /// deterministic for tests and the diagnostic-friendly enumeration
    /// order matches the macOS docs.
    public static let recognizedExtensions: [String] = [
        "png", "jpg", "jpeg", "tiff", "tif", "heic", "pdf",
    ]

    /// Whether `filename` looks like a screenshot macOS just wrote out.
    ///
    /// macOS names screenshots `"<prefix> <date> at <time>.<ext>"` where
    /// `<prefix>` defaults to the localized word for "Screenshot" (the
    /// English default literally being `"Screenshot"`). Users can
    /// override the prefix with
    /// `defaults write com.apple.screencapture name "MyShot"`, which
    /// is why the prefix is a parameter, not a constant.
    ///
    /// We accept three filename shapes so non-default-but-still-valid
    /// names match:
    ///   - `"Screenshot 2026-05-28 at 10.13.42 AM.png"` (default, space-separated)
    ///   - `"Screenshot_2026-05-28_at_10.13.42.png"` (some keyboard-shortcut tools)
    ///   - `"Screenshot.png"` (when the user has already taken one this
    ///     second — rare, but the OS handles it by appending nothing then
    ///     numbering subsequent files)
    ///
    /// The extension match is case-insensitive (macOS does sometimes
    /// uppercase extensions when re-exported via Preview).
    public static func isLikelyScreenshot(
        filename: String,
        screencapturePrefix: String = "Screenshot"
    ) -> Bool {
        guard !filename.isEmpty else { return false }
        guard !screencapturePrefix.isEmpty else { return false }

        // Reject dotfiles — `screencapture` never writes a dotfile, but a
        // sloppy substring match could otherwise mis-identify
        // `.Screenshot 2026...` (which Finder sometimes creates as a
        // temp file during atomic rename).
        guard !filename.hasPrefix(".") else { return false }

        // Extension check (case-insensitive).
        let ext = (filename as NSString).pathExtension.lowercased()
        guard recognizedExtensions.contains(ext) else { return false }

        // Strip the extension and compare the stem against the prefix.
        let stem = (filename as NSString).deletingPathExtension
        if stem == screencapturePrefix { return true }
        if stem.hasPrefix(screencapturePrefix + " ") { return true }
        if stem.hasPrefix(screencapturePrefix + "_") { return true }
        return false
    }

    /// Resolve the directory macOS writes screenshots to. Honors the
    /// `location` key of the `com.apple.screencapture` UserDefaults
    /// domain (this is what `defaults write com.apple.screencapture
    /// location ~/Pictures/Screenshots` mutates). Falls back to
    /// `<home>/Desktop`.
    ///
    /// Accepts `~` and `~user` paths exactly as the screencapture daemon
    /// does — both via `NSString.expandingTildeInPath`.
    public static func resolveLocation(
        screenCaptureDefaults: [String: Any]?,
        home: URL
    ) -> URL {
        if let dict = screenCaptureDefaults,
           let raw = dict["location"] as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let expanded = (trimmed as NSString).expandingTildeInPath
                // Defensive: collapse "" → home/Desktop. NSString already
                // returns the input unchanged for non-~ strings, so the
                // expanded path is safe to wrap.
                return URL(fileURLWithPath: expanded, isDirectory: true)
            }
        }
        return home.appendingPathComponent("Desktop", isDirectory: true)
    }

    /// Resolve the filename prefix screencapture uses. Honors the `name`
    /// key of `com.apple.screencapture`. Falls back to `"Screenshot"`,
    /// which is the literal English default — note that macOS uses the
    /// system localization here, so in a French OS this would be
    /// `"Capture d'écran"` (and the user could override via `defaults`).
    /// We can't easily learn the localized default at runtime without
    /// poking at private screencapture state; users on non-English
    /// systems who want the auto-copy feature should either set
    /// `com.apple.screencapture name "Screenshot"` or wait for a future
    /// patch that introspects `CFLocaleCopyCurrent`.
    public static func resolvePrefix(
        screenCaptureDefaults: [String: Any]?
    ) -> String {
        if let dict = screenCaptureDefaults,
           let raw = dict["name"] as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "Screenshot"
    }

    /// Filter a directory listing down to NEW screenshot files — files
    /// that match the screenshot pattern AND aren't in `knownPaths`.
    /// Returns absolute paths (concatenated from `directory` +
    /// filename) so the caller can read them without further work.
    ///
    /// Tests pump this with synthetic directory contents to exercise
    /// the watcher's diff-against-baseline logic without touching the
    /// real filesystem or DispatchSource.
    public static func filterNewScreenshots(
        in directory: URL,
        directoryContents: [String],
        knownPaths: Set<String>,
        screencapturePrefix: String = "Screenshot"
    ) -> [URL] {
        var out: [URL] = []
        for name in directoryContents {
            let absolute = directory.appendingPathComponent(name).path
            if knownPaths.contains(absolute) { continue }
            if isLikelyScreenshot(filename: name,
                                  screencapturePrefix: screencapturePrefix) {
                out.append(URL(fileURLWithPath: absolute))
            }
        }
        return out
    }
}
