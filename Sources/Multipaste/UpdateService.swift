// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import MultipasteCore

/// Wraps `UpdateChecker` with a real network fetch and a small scheduler.
///
/// - On launch, after a short grace period, perform one check.
/// - Every 24h while the app stays running, check again.
/// - The menu bar's "Check for Updates…" action triggers a manual check
///   that ALSO surfaces "up to date" (silent checks only alert on updates).
final class UpdateService {

    private let prefs: Preferences
    private let currentVersion: SemanticVersion
    private let endpoint: URL
    private var timer: Timer?

    init(prefs: Preferences,
         currentVersion: String = MultipasteVersion.value,
         endpoint: URL = URL(string: "https://api.github.com/repos/NewdlDewdl/multipaste/releases/latest")!) {
        self.prefs = prefs
        self.currentVersion = SemanticVersion(currentVersion) ?? SemanticVersion(major: 0, minor: 0, patch: 0)
        self.endpoint = endpoint
    }

    /// Start the periodic background-check schedule.
    func start() {
        // First check 60s after launch — avoids hammering at login while
        // dozens of other login items are doing their thing.
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(60)) { [weak self] in
            self?.runCheck(userInitiated: false)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.runCheck(userInitiated: false)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Trigger a check from the menu. The "you're up to date" branch
    /// only surfaces UI when the user asked.
    func checkNow() {
        runCheck(userInitiated: true)
    }

    // MARK: - Implementation

    private func runCheck(userInitiated: Bool) {
        var req = URLRequest(url: endpoint, timeoutInterval: 15)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Multipaste/\(currentVersion.description)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            guard let self = self else { return }
            if let error = error {
                if userInitiated { DispatchQueue.main.async { self.surfaceError(error.localizedDescription) } }
                return
            }
            guard let data = data else {
                if userInitiated { DispatchQueue.main.async { self.surfaceError("No data from update server.") } }
                return
            }
            do {
                let release = try UpdateChecker.parseGitHubRelease(data)
                let skipped: SemanticVersion?
                if userInitiated {
                    // User explicitly asked — ignore Skip preference so they
                    // can re-discover what they previously skipped.
                    skipped = nil
                } else {
                    skipped = self.skippedVersion()
                }
                let status = UpdateChecker.compare(
                    current: self.currentVersion,
                    latest: release.version,
                    latestURL: release.url,
                    notes: release.notes,
                    skippedVersion: skipped
                )
                DispatchQueue.main.async {
                    self.present(status: status, userInitiated: userInitiated)
                }
            } catch {
                if userInitiated {
                    DispatchQueue.main.async {
                        self.surfaceError("Couldn't parse the latest release. (\(error))")
                    }
                }
            }
        }.resume()
    }

    private func present(status: UpdateChecker.Status, userInitiated: Bool) {
        switch status {
        case .upToDate:
            if userInitiated { surfaceUpToDate() }
        case .updateAvailable(let version, let url, let notes):
            surfaceUpdate(version: version, url: url, notes: notes)
        }
    }

    private func surfaceUpToDate() {
        let alert = NSAlert()
        alert.messageText = "You're on the latest version."
        alert.informativeText = "Multipaste \(currentVersion.description) is the most recent release."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func surfaceError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't check for updates."
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func surfaceUpdate(version: SemanticVersion, url: URL, notes: String) {
        let alert = NSAlert()
        alert.messageText = "Multipaste \(version.description) is available."
        // The short prefix in informativeText is plain text by design —
        // it's a single line summarizing the version change. The
        // formatted release notes go in the accessory view below where
        // markdown can render properly (bold, monospaced code, etc.).
        alert.informativeText = "You're running \(currentVersion.description). " +
            "Here's what's new:"

        alert.accessoryView = Self.makeReleaseNotesView(rawNotes: notes)

        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Skip This Version")
        alert.addButton(withTitle: "Remind Me Later")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(url)
        case .alertSecondButtonReturn:
            setSkippedVersion(version)
        default:
            break
        }
    }

    /// Build the release-notes accessory view shown in the update
    /// dialog. Steps:
    ///   1. `ReleaseNotesFormatter.summary` extracts the user-facing
    ///      summary from the (potentially-engineer-detailed) full
    ///      changelog body — drops the `## VERSION` header, stops at
    ///      the first `### ` engineer-subsection.
    ///   2. `MarkdownAttributedString.render` styles inline markdown
    ///      (**bold**, `code`, [links], *italic*) so the dialog
    ///      doesn't show literal sigils.
    ///   3. Wrap in a scrollable, non-editable `NSTextView` sized to
    ///      fit the alert. The text view selects text + handles link
    ///      clicks, so users can copy a snippet or open a referenced
    ///      URL from the release notes.
    ///
    /// Fallback: if the summary is empty (e.g. the release body was
    /// empty), show "(release notes unavailable — see GitHub)" so the
    /// dialog never has a blank accessory view.
    private static func makeReleaseNotesView(rawNotes: String) -> NSView {
        let summary = ReleaseNotesFormatter.summary(from: rawNotes)
        let body: NSAttributedString
        if summary.isEmpty {
            body = NSAttributedString(
                string: "(release notes unavailable — see GitHub)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ])
        } else {
            body = MarkdownAttributedString.render(summary)
        }

        // Sized to look balanced inside an NSAlert. NSAlert handles its
        // own width based on messageText + buttons; we constrain the
        // accessory to ~520pt wide and let the text view's intrinsic
        // height determine the height — capped at 240 so a very long
        // release-note doesn't push the dialog off-screen.
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        // Link clicks should open in the browser, not try to navigate
        // inside a non-editable text view.
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]
        textView.textStorage?.setAttributedString(body)

        // Lay out to find the natural height, then cap.
        let containerWidth: CGFloat = 520
        textView.frame = NSRect(x: 0, y: 0, width: containerWidth, height: 1000)
        textView.textContainer?.containerSize = NSSize(
            width: containerWidth - 8, height: .greatestFiniteMagnitude)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let naturalHeight = textView.layoutManager?.usedRect(
            for: textView.textContainer!).height ?? 100
        let height = max(60, min(240, naturalHeight + 14))

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: height))
        scroll.hasVerticalScroller = (naturalHeight + 14 > height)
        scroll.hasHorizontalScroller = false
        scroll.borderType = .bezelBorder
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        scroll.documentView = textView
        return scroll
    }

    // MARK: - Skip-version persistence

    private static let skippedKey = "skippedUpdateVersion"

    private func skippedVersion() -> SemanticVersion? {
        guard let raw = UserDefaults.standard.string(forKey: Self.skippedKey) else { return nil }
        return SemanticVersion(raw)
    }

    private func setSkippedVersion(_ version: SemanticVersion) {
        UserDefaults.standard.set(version.description, forKey: Self.skippedKey)
    }
}
