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
        alert.informativeText = """
            You're running \(currentVersion.description).

            Release notes:
            \(notes.prefix(800))
            """
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
