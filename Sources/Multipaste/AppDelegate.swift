import AppKit
import MultipasteCore

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let prefs = Preferences(defaults: .standard)
    private lazy var store: HistoryStore = HistoryStore(
        directory: AppPaths.dataDirectory,
        maxItems: prefs.maxHistory
    )
    private lazy var monitor = ClipboardMonitor(store: store)
    private let hotKeyManager = HotKeyManager()
    private lazy var snippetEngine = SnippetEngine(store: store)
    private lazy var picker = PickerWindow(store: store, onPick: { [weak self] item in
        self?.pickAndPaste(item)
    }, onEditTrigger: { [weak self] item in
        self?.promptForTrigger(item: item)
    })
    private lazy var settings = SettingsWindowController(
        prefs: prefs,
        store: store,
        onHotkeyChanged: { [weak self] hk in self?.rebindHotkey(hk) },
        onLaunchAtLoginChanged: { enabled in
            // Prefer the modern Login Item API; fall back to the legacy
            // LaunchAgent toggle for installs that came through install.sh.
            if enabled { LoginItem.enable() } else { LoginItem.disable() }
            LoginAgent.setEnabled(enabled)
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
        onPasteItem:  { [weak self] item in self?.pickAndPaste(item) },
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

        // First-run experience: show Welcome window once. On subsequent
        // launches the menu bar icon + hotkey are enough.
        if !prefs.hasCompletedFirstRun {
            // If running from /Applications or ~/Applications, auto-enable
            // login item on behalf of the user (they can flip it off in
            // the Welcome window). If running from elsewhere (Downloads,
            // Desktop), DON'T auto-register — that path would silently
            // unregister itself the moment the user moves the app.
            if isInApplicationsFolder() {
                LoginItem.enable()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
                self?.welcome.show()
            }
        }
    }

    /// True if Multipaste.app currently lives in /Applications or ~/Applications.
    private func isInApplicationsFolder() -> Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/")
            || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    private func afterWelcomeDismissed() {
        // No-op for now — kept as a hook for future setup steps.
    }

    /// Called by `PermissionMonitor` whenever the Accessibility-trust
    /// state flips. We use this to:
    ///   - update the menu bar icon (banner row, dimmed icon)
    ///   - re-start the snippet engine the moment access is granted
    ///   - surface a quick toast so the user knows it worked
    private func handlePermissionChange(granted: Bool) {
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
    private func pickAndPaste(_ item: ClipboardItem) {
        Paster.put(item)
        guard prefs.pasteOnSelect else { return }

        if Permissions.isTrustedForAccessibility {
            // Give the focused app a beat to regain key-window status.
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80)) {
                Paster.simulateCommandV()
            }
        } else {
            // Show a one-time prompt and skip paste — the user still has
            // the item on their clipboard and can ⌘V manually.
            Permissions.promptForAccessibility()
        }
    }
}
