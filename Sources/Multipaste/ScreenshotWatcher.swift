// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import MultipasteCore

/// Watches the macOS screenshot save directory and auto-copies new
/// screenshots to `NSPasteboard.general` as they appear.
///
/// macOS's default screenshot workflow (⌘⇧3, ⌘⇧4, ⌘⇧5) saves to disk and
/// only copies to the clipboard when the user remembers to hold ⌃ — most
/// people don't. With this watcher running, every screenshot lands on the
/// clipboard automatically, which means it also lands in Multipaste's
/// history (the existing `ClipboardMonitor` polls `changeCount` and picks
/// up the write within 300 ms).
///
/// ## How it works
///
/// 1. Read `com.apple.screencapture` UserDefaults to find the user's
///    configured location (default `~/Desktop`) and filename prefix
///    (default `"Screenshot"`). Both can be changed by
///    `defaults write com.apple.screencapture {location,name} …`.
/// 2. Open the directory with `open(O_EVTONLY)` and attach a
///    `DispatchSource.makeFileSystemObjectSource` watcher for
///    `[.write, .extend, .rename, .link]` events. Each fire means
///    something in that directory changed.
/// 3. On each fire, list the directory, diff against the baseline of
///    paths we already saw, and pull out any NEW files whose name
///    matches the screenshot pattern (see `ScreenshotDetector`).
/// 4. Read the file, write it to `NSPasteboard.general` as PNG + TIFF
///    so any consumer (image-only paste, Finder drop target, etc.)
///    gets a usable representation.
///
/// `DispatchSource` over `FSEvents`: the FSEvents C API requires a
/// retained-context pointer and a global callback function; for one
/// directory at low event rate, a `DispatchSource.makeFileSystemObjectSource`
/// is dramatically less code and just as reliable. The
/// `kFSEventStreamCreateFlagFileEvents` granularity (per-file events) is
/// the only thing FSEvents would have added, and we don't need it —
/// we re-scan the directory on every mtime bump.
///
/// ## Why baseline at start
///
/// The user may have hundreds of pre-existing screenshots on the Desktop
/// when Multipaste launches for the first time. We do NOT want to copy
/// those — they're old. So at start, we populate `seenPaths` with the
/// current directory listing and only react to ADDITIONS from that
/// point on. The mtime-event watcher only fires on changes, so we
/// don't waste cycles on the baseline.
///
/// ## TCC implications
///
/// macOS Catalina+ requires user consent for any app to read
/// `~/Desktop`. The first time we call `contentsOfDirectory`, macOS
/// shows the "Multipaste would like to access files in your Desktop
/// folder" dialog. Denying it makes the watcher silently no-op — we
/// log the failure to `multipaste.log` for diagnostics. Granting it
/// once is permanent.
///
/// ## Preference flow
///
/// Read `prefs.autoCopyScreenshots` on `start()`. Toggle via the
/// Settings UI calls `reloadSettings()` which `stop()`s the source,
/// re-reads prefs, and `start()`s again (only if the toggle is on).
final class ScreenshotWatcher {

    private let prefs: Preferences
    private let pasteboard: NSPasteboard
    private let logger: (String) -> Void

    /// Active dispatch source, nil when stopped. The corresponding fd is
    /// closed via the source's cancel handler.
    private var source: DispatchSourceFileSystemObject?
    private var watchedFD: CInt = -1

    /// Resolved location + prefix at `start()` time. Captured so we don't
    /// re-resolve UserDefaults on every event (those reads can be slow
    /// under contention with the screencapture daemon).
    private var watchedDirectory: URL?
    private var screencapturePrefix: String = "Screenshot"

    /// Snapshot of the directory's contents at `start()` plus everything
    /// we've already processed. Used to compute the "what's new?" diff.
    /// Stored as absolute paths so we can pass them straight to the
    /// detector.
    private var seenPaths: Set<String> = []

    /// All file-system work happens on this queue. `NSPasteboard` writes
    /// are explicitly hopped to `.main` so AppKit invariants hold.
    private let scanQueue = DispatchQueue(
        label: "com.rohin.multipaste.screenshot-watcher",
        qos: .utility)

    /// Resolves `(directory, prefix)` at `start()` time. Production
    /// supplies the default that reads `com.apple.screencapture`
    /// UserDefaults; the smoke-test injects a closure pointing at a
    /// temp dir so it can exercise the full pipeline without
    /// mutating the user's real screencapture settings.
    typealias SettingsResolver = () -> (URL, String)

    private let settingsResolver: SettingsResolver

    init(prefs: Preferences,
         pasteboard: NSPasteboard = .general,
         settingsResolver: SettingsResolver? = nil,
         logger: @escaping (String) -> Void = { msg in
            // Default logger writes to the Diagnostics log so failures
            // are debuggable via the menu-bar's Diagnostics… view.
            Diagnostics.log(msg)
         }) {
        self.prefs = prefs
        self.pasteboard = pasteboard
        self.settingsResolver = settingsResolver ?? Self.readScreencaptureDefaults
        self.logger = logger
    }

    deinit {
        // Best-effort tear-down; the cancel handler closes the fd.
        source?.cancel()
    }

    /// Start watching the configured screenshot directory. No-op if
    /// the pref is off, the directory is missing, or we're already
    /// watching.
    func start() {
        guard prefs.autoCopyScreenshots else {
            logger("ScreenshotWatcher: skipped start — autoCopyScreenshots preference is OFF")
            return
        }
        guard source == nil else { return }

        let (dir, prefix) = settingsResolver()
        watchedDirectory = dir
        screencapturePrefix = prefix

        baselineDirectory(dir)
        if !attachWatcher(to: dir) {
            logger("ScreenshotWatcher: failed to attach watcher at \(dir.path). " +
                   "macOS may have denied Multipaste access to that folder — check " +
                   "System Settings → Privacy & Security → Files and Folders.")
            return
        }
        logger("ScreenshotWatcher: watching \(dir.path) with prefix \"\(prefix)\" (\(seenPaths.count) existing files baselined)")
    }

    /// Tear down the dispatch source. Idempotent.
    func stop() {
        source?.cancel()
        source = nil
        seenPaths.removeAll()
        watchedDirectory = nil
    }

    /// Apply preference changes — toggling on/off, or pointing at a new
    /// `defaults write com.apple.screencapture location` value. Cheaper
    /// than rebuilding the whole app; just bounces the watcher.
    func reloadSettings() {
        stop()
        start()
    }

    /// True when the watcher is currently observing a directory. Exposed
    /// for the Diagnostics view.
    var isWatching: Bool { source != nil }

    // MARK: - Internals

    /// Default settings resolver: snapshot the macOS screencapture
    /// defaults via a transient `UserDefaults(suiteName:)` and resolve
    /// through the pure `ScreenshotDetector` helpers.
    ///
    /// We could read these from `defaults read com.apple.screencapture`,
    /// but the UserDefaults API does the right thing — it shells out to
    /// `cfprefsd` so we get the same answer the screencapture daemon
    /// sees. (Edge case: if a `defaults write` happens while we're
    /// running, the cfprefsd cache may take a tick to propagate. The
    /// reload-on-toggle path covers the user-driven case; pathological
    /// cases need a Quit & Relaunch, same as most macOS prefs.)
    private static func readScreencaptureDefaults() -> (URL, String) {
        let domain = UserDefaults(suiteName: "com.apple.screencapture")
        let snapshot = domain?.dictionaryRepresentation() ?? [:]
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return (
            ScreenshotDetector.resolveLocation(
                screenCaptureDefaults: snapshot, home: home),
            ScreenshotDetector.resolvePrefix(
                screenCaptureDefaults: snapshot)
        )
    }

    /// Populate `seenPaths` with the current directory contents so
    /// pre-existing files don't trigger a stampede of auto-copies on
    /// first start.
    private func baselineDirectory(_ dir: URL) {
        let names = (try? FileManager.default
            .contentsOfDirectory(atPath: dir.path)) ?? []
        seenPaths = Set(names.map { dir.appendingPathComponent($0).path })
    }

    /// Open the directory with `O_EVTONLY` (read-only, no consumption
    /// of the inode for other purposes) and create a Dispatch source
    /// for the events we care about.
    ///
    /// `O_EVTONLY` is critical: a regular `open(O_RDONLY)` would prevent
    /// the volume from unmounting cleanly, which would cause spurious
    /// "disk in use" alerts when the user disconnects an external drive
    /// they happen to be using as their screenshot location.
    private func attachWatcher(to dir: URL) -> Bool {
        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return false }
        watchedFD = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            // - .write: contents changed (file added/removed/renamed in)
            // - .extend: file appended to (rare for our case)
            // - .rename: directory itself was renamed
            // - .link: hard-link count changed (mv between dirs on same vol)
            eventMask: [.write, .extend, .rename, .link],
            queue: scanQueue)

        src.setEventHandler { [weak self] in
            self?.scan()
        }
        src.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.watchedFD >= 0 {
                close(self.watchedFD)
                self.watchedFD = -1
            }
        }
        src.resume()
        source = src
        return true
    }

    /// Scan the directory, compute the diff against `seenPaths`,
    /// auto-copy anything that looks like a new screenshot.
    private func scan() {
        guard let dir = watchedDirectory else { return }
        let names = (try? FileManager.default
            .contentsOfDirectory(atPath: dir.path)) ?? []
        let newURLs = ScreenshotDetector.filterNewScreenshots(
            in: dir,
            directoryContents: names,
            knownPaths: seenPaths,
            screencapturePrefix: screencapturePrefix)

        // Update baseline BEFORE attempting the copy so a partial-write
        // failure doesn't cause infinite re-fires.
        seenPaths.formUnion(names.map { dir.appendingPathComponent($0).path })

        for url in newURLs {
            copyScreenshotToPasteboard(at: url)
        }
    }

    /// Read the file as image data and publish PNG + TIFF (plus the
    /// native format if it's neither) representations to the pasteboard
    /// on the main queue.
    ///
    /// Why three representations:
    ///   - **PNG** is the universal expectation. Slack/iMessage/Discord/
    ///     image editors all read PNG.
    ///   - **TIFF** is `NSPasteboard`'s lossless legacy universal — some
    ///     older inline-image-paste paths still read TIFF only.
    ///   - **Native** (e.g. JPEG/HEIC/PDF) preserves the exact bytes the
    ///     user's `screencapture` setting produced, so a consumer that
    ///     asks for the originating format gets it byte-for-byte.
    ///
    /// Retry loop: `screencapture` writes atomically (writes to a temp
    /// path then renames), so by the time the watcher's directory-mtime
    /// event fires, the file is fully written. But just in case the
    /// kernel batched a couple of events, we retry the read up to 3
    /// times with a 50ms backoff.
    private func copyScreenshotToPasteboard(at url: URL) {
        var data: Data?
        for attempt in 0..<3 {
            if attempt > 0 { Thread.sleep(forTimeInterval: 0.05) }
            data = try? Data(contentsOf: url)
            if let d = data, !d.isEmpty { break }
        }
        guard let imageData = data, !imageData.isEmpty else {
            logger("ScreenshotWatcher: empty data at \(url.path) after 3 retries, skipping")
            return
        }
        guard let image = NSImage(data: imageData) else {
            logger("ScreenshotWatcher: not an image at \(url.path), skipping")
            return
        }

        let nativeType = pasteboardType(forExtension: url.pathExtension)
        let pngData: Data? = (nativeType == .png) ? imageData : encodedPNG(from: image)
        let tiffData: Data? = image.tiffRepresentation

        // Assemble the (type, data) pairs we'll publish. Order matters
        // only for `declareTypes` (the first type in the list is the
        // pasteboard's "primary" representation for some consumers); PNG
        // first matches modern-app expectations.
        var writes: [(NSPasteboard.PasteboardType, Data)] = []
        if let png = pngData { writes.append((.png, png)) }
        if let tiff = tiffData { writes.append((.tiff, tiff)) }
        if let native = nativeType, native != .png, native != .tiff {
            writes.append((native, imageData))
        }

        guard !writes.isEmpty else {
            logger("ScreenshotWatcher: no encodable representations at \(url.path), skipping")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pasteboard.clearContents()
            self.pasteboard.declareTypes(writes.map { $0.0 }, owner: nil)
            for (type, data) in writes {
                self.pasteboard.setData(data, forType: type)
            }
            self.logger("ScreenshotWatcher: copied \(url.lastPathComponent) (\(imageData.count) bytes, \(writes.count) representations) to pasteboard")
        }
    }

    /// Map a file extension to its canonical pasteboard type. Returns
    /// nil when we don't have a clean canonical type — caller then
    /// falls back to TIFF, which every macOS image consumer accepts.
    private func pasteboardType(forExtension ext: String) -> NSPasteboard.PasteboardType? {
        switch ext.lowercased() {
        case "png":          return .png
        case "tiff", "tif":  return .tiff
        case "pdf":          return .pdf
        case "jpg", "jpeg":  return NSPasteboard.PasteboardType("public.jpeg")
        case "heic":         return NSPasteboard.PasteboardType("public.heic")
        default:             return nil
        }
    }

    /// Encode an `NSImage` back to PNG. Used when the source file isn't
    /// PNG (e.g. user set `screencapture type heic`) so we can still
    /// publish a PNG representation that maximally-compatible consumers
    /// like Slack can paste.
    private func encodedPNG(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
