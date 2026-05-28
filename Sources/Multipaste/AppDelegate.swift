// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import MultipasteCore

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let prefs = Preferences(defaults: .standard)
    private lazy var store: HistoryStore = HistoryStore(
        directory: AppPaths.dataDirectory,
        maxItems: prefs.maxHistory
    )
    private lazy var monitor = ClipboardMonitor(store: store, prefs: prefs)
    private lazy var screenshotWatcher = ScreenshotWatcher(prefs: prefs)
    private let hotKeyManager = HotKeyManager()
    private lazy var snippetEngine = SnippetEngine(store: store)
    private lazy var picker = PickerWindow(
        store: store,
        prefs: prefs,
        onPick: { [weak self] item, previousApp in
            self?.pickAndPaste(item, previousApp: previousApp)
        },
        onEditTrigger: { [weak self] item in
            self?.promptForTrigger(item: item)
        }
    )
    private lazy var settings = SettingsWindowController(
        prefs: prefs,
        store: store,
        onHotkeyChanged: { [weak self] hk in self?.rebindHotkey(hk) },
        onLaunchAtLoginChanged: { enabled in
            // Single supervisor: SMAppService Login Item. The legacy
            // LaunchAgent is migrated away on startup (see
            // migrateLaunchAgentToLoginItem in AppDelegate).
            if enabled { LoginItem.enable() } else { LoginItem.disable() }
        },
        onAutoCopyScreenshotsChanged: { [weak self] _ in
            // Bounce the watcher: the toggle's new value is already in
            // prefs by the time this fires, and `reloadSettings()` will
            // stop the source if the pref just went off, or start one
            // if it just went on.
            self?.screenshotWatcher.reloadSettings()
        }
    )
    private lazy var welcome = WelcomeWindow(prefs: prefs) { [weak self] in
        self?.afterWelcomeDismissed()
    }
    private lazy var updateService = UpdateService(prefs: prefs)
    private let permissionMonitor = PermissionMonitor()
    private lazy var menubar = MenuBarController(
        store: store,
        monitor: monitor,
        prefs: prefs,
        initialAccessibilityGranted: Permissions.isTrustedForAccessibility,
        onShowPicker: { [weak self] in self?.picker.show() },
        onPasteItem:  { [weak self] item in self?.pickAndPaste(item, previousApp: nil) },
        onShowSettings: { [weak self] in self?.settings.show() },
        onCheckForUpdates: { [weak self] in self?.updateService.checkNow() },
        onGrantAccessibility: { [weak self] in self?.walkThroughAccessibilityGrant() },
        onRelaunch:   { [weak self] in self?.relaunch() },
        onQuit:       { NSApp.terminate(nil) }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon — this is a menu-bar app.
        NSApp.setActivationPolicy(.accessory)

        // Touch lazy props so they wire up.
        _ = menubar
        _ = picker

        monitor.start()
        // The screenshot watcher writes to NSPasteboard.general; the
        // ClipboardMonitor (already started above) sees the changeCount
        // bump on its next 300ms tick and inserts the image into history
        // just like any other ⌘C. No special integration needed.
        screenshotWatcher.start()
        hotKeyManager.register(prefs.hotkey) { [weak self] in
            self?.picker.show()
        }
        // Snippet engine is a no-op without Accessibility consent. We try
        // to start it now; if the user grants permission later, the engine
        // will re-attempt on the next app launch (LaunchAgent restarts us
        // on consent changes is not automatic — quit + reopen, or just wait
        // for next login). We could re-attempt every N seconds; the simple
        // path is enough for v1.1.
        snippetEngine.start()
        updateService.start()

        permissionMonitor.onChange = { [weak self] granted in
            self?.handlePermissionChange(granted: granted)
        }
        permissionMonitor.onBurstTimeout = { [weak self] in
            self?.showRelaunchNeededAlert()
        }
        permissionMonitor.start()

        // Refresh trust when the user comes back to Multipaste from
        // System Settings — gives instant feedback in addition to the
        // poll, and helps when AXIsProcessTrusted() is sluggish to
        // update across context switches.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.permissionMonitor.refresh() }

        // Supervisor convergence: SMAppService Login Item is the ONE
        // supervisor for auto-start. The LaunchAgent path (used by
        // install.sh in v1.0–1.5) is removed because LaunchAgent-
        // supervised processes don't inherit the user's Accessibility
        // TCC grant — AXIsProcessTrusted() returns false even after
        // the user toggles Multipaste on in System Settings. Same .app,
        // same cdhash, same designated requirement — just a different
        // launch context, and TCC says no.
        //
        // Migration: if a LaunchAgent plist from a previous install
        // still exists, unload it and delete it now. Then register
        // SMAppService so the app starts at login via the Login Items
        // mechanism that System Settings → General → Login Items
        // surfaces.
        migrateLaunchAgentToLoginItem()

        // First-run: auto-enable Login Item if we're installed in an
        // Applications folder. (`SMAppService.mainApp.register()`
        // requires the bundle to live in /Applications or
        // ~/Applications — running from ~/Downloads silently fails.)
        if !prefs.hasCompletedFirstRun {
            if isInApplicationsFolder() {
                LoginItem.enable()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
                self?.welcome.show()
            }
        }
    }

    /// Path to Multipaste.app's containing Applications folder, used by
    /// SMAppService.mainApp.register() — must be /Applications or
    /// ~/Applications, not Downloads/Desktop.
    private func isInApplicationsFolder() -> Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/")
            || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    /// One-shot migration: if a LaunchAgent plist from a previous
    /// install version exists, unload it and delete it. The LaunchAgent
    /// path was abandoned in 1.6.0 because LaunchAgent-launched processes
    /// don't inherit user TCC grants on macOS Tahoe.
    private func migrateLaunchAgentToLoginItem() {
        let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/com.rohin.multipaste.plist"
        guard FileManager.default.fileExists(atPath: plistPath) else { return }

        FileHandle.standardError.write(Data(
            "[multipaste] migrating from LaunchAgent to SMAppService Login Item\n".utf8
        ))
        let uid = String(getuid())
        for args in [
            ["bootout", "gui/\(uid)/com.rohin.multipaste"],
            ["disable", "gui/\(uid)/com.rohin.multipaste"],
        ] {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = args
            // /dev/null over Pipe() — no risk of a chatty future
            // launchctl filling an unread pipe.
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            do { try task.run(); task.waitUntilExit() } catch {}
        }
        try? FileManager.default.removeItem(atPath: plistPath)
    }

    private func afterWelcomeDismissed() {
        // No-op for now — kept as a hook for future setup steps.
    }

    /// Called by `PermissionMonitor` whenever the Accessibility-trust
    /// state flips. We use this to:
    ///   - log the transition to the known log file
    ///   - update the menu bar icon (banner row, dimmed icon)
    ///   - re-start the snippet engine the moment access is granted
    ///   - surface a quick toast so the user knows it worked
    private func handlePermissionChange(granted: Bool) {
        Diagnostics.log("Accessibility trust flipped to \(granted ? "ON" : "OFF")")
        menubar.setAccessibilityGranted(granted)
        if granted {
            // Snippet engine's tap was a no-op before. Kick it back up.
            snippetEngine.stop()
            snippetEngine.start()
            announceAccessibilityGranted()
        }
    }

    private func announceAccessibilityGranted() {
        let alert = NSAlert()
        alert.messageText = "Accessibility access granted!"
        alert.informativeText = """
            Auto-paste and snippet expansion are now live.

            Press \u{2318}\u{21E7}V to open the clipboard picker, or type a snippet trigger followed by space anywhere.
            """
        alert.addButton(withTitle: "Got it")
        alert.runModal()
    }

    /// Triggered from the menu-bar banner. Combines:
    ///   1. AXIsProcessTrustedWithOptions(prompt: true) — adds Multipaste
    ///      to the Accessibility list so it's not "Where is it??"
    ///   2. Deep-link to the Accessibility pane
    ///   3. Step-by-step alert with the exact UI path
    ///   4. Burst-poll mode so detection is near-instant
    func walkThroughAccessibilityGrant() {
        Permissions.walkUserThroughAccessibilityGrant()
        permissionMonitor.burstPoll(duration: 60.0)
        let alert = NSAlert()
        alert.messageText = "Grant Accessibility access to Multipaste"
        alert.informativeText = """
            I just opened System Settings and added Multipaste to the Accessibility list.

            Steps:
              1. In the window that just appeared (System Settings → Privacy & Security → Accessibility), find Multipaste in the list.
              2. Flip the toggle next to it to ON.
              3. macOS will ask for Touch ID or your password — confirm.

            Multipaste is checking 4 times per second for the next minute, so the icon will brighten within a heartbeat of you flipping the switch.

            If the icon doesn't brighten after a few seconds: macOS sometimes holds the old permission state for a running process. Click "Quit & Relaunch" and the new Multipaste will pick it up immediately.

            Why this is needed: auto-paste (synthesizing \u{2318}V into the focused app) and snippet expansion (replacing your trigger text) both require Accessibility. Without it, picks still land on your clipboard and you can \u{2318}V manually.
            """
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Settings Again")
        alert.addButton(withTitle: "Quit & Relaunch")
        switch alert.runModal() {
        case .alertSecondButtonReturn:
            Permissions.walkUserThroughAccessibilityGrant()
        case .alertThirdButtonReturn:
            relaunch()
        default:
            break
        }
    }

    /// Show a fallback "this looks stuck — relaunch" alert. Triggered
    /// by PermissionMonitor when its burst-poll window elapses without
    /// detecting a state change. Covers the case where macOS's TCC
    /// cache pins the running process to its old answer.
    private func showRelaunchNeededAlert() {
        guard !Permissions.isTrustedForAccessibility else { return }
        let alert = NSAlert()
        alert.messageText = "Did you grant Accessibility access?"
        alert.informativeText = """
            Multipaste didn't pick up a permission change in the last minute. If you did toggle Multipaste on in System Settings, macOS sometimes caches the old state for a running app — a quick relaunch picks it up.

            (If you didn't toggle anything yet: click "Open Settings Again".)
            """
        alert.addButton(withTitle: "Quit & Relaunch")
        alert.addButton(withTitle: "Open Settings Again")
        alert.addButton(withTitle: "Not Now")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            relaunch()
        case .alertSecondButtonReturn:
            walkThroughAccessibilityGrant()
        default:
            break
        }
    }

    /// Spawn a fresh instance of this .app, then quit ourselves a beat
    /// later. The new process gets a clean read of the Accessibility
    /// trust bit, so any per-process TCC cache is bypassed.
    func relaunch() {
        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: cfg) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                NSApp.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        screenshotWatcher.stop()
        hotKeyManager.unregister()
        snippetEngine.stop()
    }

    // MARK: - Helpers

    private func rebindHotkey(_ hotkey: Hotkey) {
        hotKeyManager.register(hotkey) { [weak self] in self?.picker.show() }
    }

    private func promptForTrigger(item: ClipboardItem) {
        SnippetEditor.prompt(initial: item.trigger ?? "",
                             previewText: item.preview) { [weak self] newTrigger in
            guard let self = self else { return }
            let normalized = newTrigger?.isEmpty == false ? newTrigger : nil
            self.store.setTrigger(id: item.id, trigger: normalized)
        }
    }

    /// Pasteboard-set + (optionally) synthesize ⌘V into whatever app
    /// had focus before the picker opened.
    ///
    /// The flow:
    ///  1. Write the item to the pasteboard.
    ///  2. Reactivate `previousApp` so focus returns to where it was
    ///     before the picker stole it.
    ///  3. Poll `NSWorkspace.frontmostApplication` every 20 ms (up to
    ///     500 ms) until it actually matches `previousApp`. We can't
    ///     just sleep a fixed delay — focus switching is asynchronous
    ///     and the time varies from ~30 ms to ~250 ms depending on
    ///     load. The fixed 80 ms delay v1.7.0 used was the wrong
    ///     pattern: too short on a busy machine, too long when fast.
    ///  4. Once focus has actually returned, synthesize ⌘V.
    ///
    /// If `previousApp` is nil (e.g. menu-bar quick-pick), skip the
    /// reactivation step — Multipaste's menu has already returned focus
    /// to the previous app on dismiss.
    private func pickAndPaste(_ item: ClipboardItem, previousApp: NSRunningApplication?) {
        Paster.put(item)
        guard prefs.pasteOnSelect else {
            Diagnostics.log("pickAndPaste: pasteOnSelect=off, item on clipboard only")
            return
        }
        guard Permissions.isTrustedForAccessibility else {
            Diagnostics.log("pickAndPaste: Accessibility not granted, item on clipboard only")
            Permissions.promptForAccessibility()
            return
        }

        if let target = previousApp {
            target.activate(options: [])
            Diagnostics.log("pickAndPaste: reactivating \(target.bundleIdentifier ?? "?") pid=\(target.processIdentifier)")
        }

        waitForFocus(of: previousApp, timeout: 0.5) { resolved in
            if resolved {
                Diagnostics.log("pickAndPaste: focus restored, synthesizing ⌘V")
            } else {
                Diagnostics.log("pickAndPaste: focus restore TIMED OUT, synthesizing ⌘V anyway")
            }
            Paster.simulateCommandV()
        }
    }

    /// Poll `NSWorkspace.frontmostApplication` every 20 ms until it
    /// matches `target`, or until `timeout` seconds elapse. Calls
    /// `completion` on the main queue with `resolved: true` when the
    /// target became frontmost, or `resolved: false` on timeout.
    ///
    /// If `target` is nil, fires `completion(true)` after a single
    /// 50 ms grace period — gives the menu a beat to finish dismissing.
    private func waitForFocus(of target: NSRunningApplication?,
                              timeout: TimeInterval,
                              completion: @escaping (_ resolved: Bool) -> Void) {
        if target == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
                completion(true)
            }
            return
        }
        let start = Date()
        func tick() {
            if let target = target,
               NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
                completion(true)
                return
            }
            if Date().timeIntervalSince(start) >= timeout {
                completion(false)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(20)) {
                tick()
            }
        }
        tick()
    }
}
