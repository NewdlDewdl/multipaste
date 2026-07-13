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
        onPick: { [weak self] items, previousApp, flavor in
            self?.pickAndPaste(items, previousApp: previousApp, flavor: flavor)
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
        onPasteItem:  { [weak self] item in
            guard let self else { return }
            // The menu-bar quick-pick honors "Paste as plain text by
            // default" the same way ⌘1-9 in the picker does (base flavor,
            // no Shift inversion; a menu click has no ⇧↩ affordance).
            self.pickAndPaste([item], previousApp: nil,
                              flavor: PasteFlavor.effective(
                                plainTextPasteDefault: self.prefs.plainTextPasteDefault,
                                shiftPressed: false))
        },
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

        // Listen for the `--pin-current` IPC. A one-shot `Multipaste
        // --pin-current` process posts this distributed notification; we
        // own the store, so we perform the pin (see handlePinCurrentIPC).
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handlePinCurrentIPC(_:)),
            name: MultipasteIPC.pinCurrent, object: nil)

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
        DistributedNotificationCenter.default().removeObserver(self)
        monitor.stop()
        screenshotWatcher.stop()
        hotKeyManager.unregister()
        snippetEngine.stop()
    }

    /// Handle the `--pin-current` IPC: pin whatever is on the clipboard
    /// right now. We rebuild the item from the LIVE pasteboard (same logic
    /// as the poll) and `insert` it before pinning, so there is no race
    /// with the 300 ms monitor tick: the current clipboard is guaranteed
    /// present in the store and pinned regardless of poll timing. `insert`
    /// is idempotent (dedup resurfaces an existing item, preserving its
    /// trigger/pin); `pin(contentHash:)` then sets pinned = true without
    /// ever toggling. Concealed/transient clips (password managers) snapshot
    /// to nil and are silently skipped, so a password is never pinned.
    @objc private func handlePinCurrentIPC(_ note: Notification) {
        guard let item = monitor.currentSnapshot() else {
            Diagnostics.log("pinCurrent: nothing pinnable on the clipboard (empty or concealed)")
            return
        }
        store.insert(item)
        let found = store.pin(contentHash: item.contentHash)
        Diagnostics.log("pinCurrent: \(found ? "pinned" : "insert-then-miss") \(item.kindLabel) hash=\(item.contentHash)")
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

    /// Settle window applied AFTER the paste target is confirmed to have
    /// focus, before synthesizing ⌘V. Two sub-perceptual hand-offs lag even
    /// once the target is frontmost: the key-window transfer as our panel
    /// orders out and the target's window regains key, and a
    /// freshly-activated app becoming input-ready. Posting ⌘V into that gap
    /// is what dropped pastes pre-2.2.0. A short fixed beat *after* the
    /// focus condition is met (the same trick `SnippetEngine` uses between
    /// its own synthesized keystrokes) closes it imperceptibly.
    private static let pasteSettle: TimeInterval = 0.05

    /// Deliver one or more picked items to the app the user wants to
    /// paste into. `MultiPasteComposer` decides the shape:
    ///
    ///  - `.single` / `.combined`: ONE pasteboard write + ONE ⌘V (the
    ///    classic path; combined is text joined with the user's
    ///    separator, or one merged multi-file pasteboard).
    ///  - `.sequential`: items that cannot merge (images in the mix)
    ///    paste one after another in mark order, with a settle beat
    ///    between pasteboard swaps.
    ///
    /// The combined item also flows into history automatically: the
    /// ClipboardMonitor's 300 ms poll sees the changeCount bump from
    /// `Paster.put` and inserts it like any other copy, so a merged
    /// multi-paste becomes a single reusable history item for free.
    private func pickAndPaste(_ items: [ClipboardItem],
                              previousApp: NSRunningApplication?,
                              flavor: PasteFlavor) {
        guard let plan = MultiPasteComposer.plan(items: items,
                                                 separator: prefs.multiPasteSeparator,
                                                 flavor: flavor) else { return }
        switch plan {
        case .single(let item):
            deliver(item, previousApp: previousApp, flavor: flavor, label: "single")
        case .combined(let item):
            deliver(item, previousApp: previousApp, flavor: flavor,
                    label: "combined(\(items.count) items)")
        case .sequential(let sequence):
            deliverSequentially(sequence, previousApp: previousApp, flavor: flavor)
        }
    }

    /// Write `item` to the pasteboard and (if enabled + permitted)
    /// synthesize ⌘V into the app the user actually wants to paste into.
    ///
    /// Since v2.2.0 the picker is a non-activating panel, so the app that
    /// was frontmost before it opened *stays* frontmost — the common case
    /// is simply "settle a beat, then ⌘V into it," with no activation
    /// round-trip to race against. `PasteRouting` picks the path:
    ///
    ///  - `.immediate` — previous app still frontmost (expected): settle, paste.
    ///  - `.restoreFocus` — focus somehow landed on us: hand it back
    ///    cooperatively (macOS 14+ requires the active app to *yield*
    ///    before another app's `activate()` is honored), wait for it, paste.
    ///  - `.clipboardOnly` — we're frontmost with no known target: don't
    ///    paste into ourselves; the item is on the clipboard for a manual ⌘V.
    private func deliver(_ item: ClipboardItem, previousApp: NSRunningApplication?,
                         flavor: PasteFlavor, label: String) {
        Paster.put(item, flavor: flavor)
        routeAndPaste(previousApp: previousApp, label: label) {
            Paster.simulateCommandV()
        }
    }

    /// Multi-paste fallback for un-mergeable picks (an image in the mix):
    /// paste each item in turn. The first pasteboard write happens up
    /// front so even a guard-bail leaves something useful on the
    /// clipboard; on `.clipboardOnly` we stop there; synthesizing a
    /// burst of ⌘V with no target would paste into Multipaste itself.
    private func deliverSequentially(_ items: [ClipboardItem], previousApp: NSRunningApplication?,
                                     flavor: PasteFlavor) {
        guard let first = items.first else { return }
        Paster.put(first, flavor: flavor)
        routeAndPaste(previousApp: previousApp, label: "sequential(\(items.count) items)") { [weak self] in
            self?.pasteSequentially(items, index: 0, flavor: flavor)
        }
    }

    /// Shared guard + `PasteRouting` switch for both delivery shapes.
    /// `paste` runs once the target app is ready for keystrokes (already
    /// settled); on `.clipboardOnly` it never runs; whatever the caller
    /// put on the pasteboard stays available for a manual ⌘V.
    private func routeAndPaste(previousApp: NSRunningApplication?, label: String,
                               paste: @escaping () -> Void) {
        guard prefs.pasteOnSelect else {
            Diagnostics.log("pickAndPaste[\(label)]: pasteOnSelect=off, item on clipboard only")
            return
        }
        guard Permissions.isTrustedForAccessibility else {
            Diagnostics.log("pickAndPaste[\(label)]: Accessibility not granted, item on clipboard only")
            Permissions.promptForAccessibility()
            return
        }

        let mePID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let weAreFrontmost = (frontPID == mePID)

        switch PasteRouting.route(weAreFrontmost: weAreFrontmost,
                                  hasPreviousApp: previousApp != nil) {
        case .immediate:
            Diagnostics.log("pickAndPaste[\(label)]: immediate (front=\(frontPID.map(String.init) ?? "?")), settling \(Int(Self.pasteSettle * 1000))ms then ⌘V")
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.pasteSettle) {
                paste()
            }

        case .restoreFocus:
            guard let target = previousApp else { return } // routing guarantees non-nil here
            if #available(macOS 14.0, *) {
                // Cooperative activation: we're the active app, so we must
                // yield before the target's activate() will be honored.
                NSApp.yieldActivation(to: target)
                target.activate(from: .current, options: [])
            } else {
                target.activate(options: [])
            }
            Diagnostics.log("pickAndPaste[\(label)]: restoreFocus → \(target.bundleIdentifier ?? "?") pid=\(target.processIdentifier)")
            waitForFocus(of: target, timeout: 0.5) { resolved in
                Diagnostics.log("pickAndPaste[\(label)]: focus \(resolved ? "restored" : "restore TIMED OUT"), settling then ⌘V")
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.pasteSettle) {
                    paste()
                }
            }

        case .clipboardOnly:
            Diagnostics.log("pickAndPaste[\(label)]: clipboardOnly: frontmost with no paste target; item left on clipboard")
        }
    }

    /// Paste `items[index...]` one at a time: pasteboard write, settle a
    /// beat, ⌘V, wait `sequentialInterItemDelay` for the target to have
    /// READ the pasteboard (apps read it while processing the ⌘V from
    /// their event queue; swapping sooner would feed item N+1's bytes
    /// into paste N), recurse. The last item naturally stays on the
    /// clipboard, matching single-paste semantics.
    private func pasteSequentially(_ items: [ClipboardItem], index: Int, flavor: PasteFlavor) {
        guard index < items.count else {
            Diagnostics.log("pickAndPaste[sequential]: complete (\(items.count) items)")
            return
        }
        Paster.put(items[index], flavor: flavor)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pasteSettle) { [weak self] in
            Paster.simulateCommandV()
            DispatchQueue.main.asyncAfter(
                deadline: .now() + MultiPasteComposer.sequentialInterItemDelay
            ) {
                self?.pasteSequentially(items, index: index + 1, flavor: flavor)
            }
        }
    }

    /// Poll `NSWorkspace.frontmostApplication` every 20 ms until it matches
    /// `target`, or until `timeout` seconds elapse. Calls `completion` on
    /// the main queue with `resolved: true` when the target became
    /// frontmost, or `false` on timeout. Used only by the `.restoreFocus`
    /// fallback in `pickAndPaste`.
    private func waitForFocus(of target: NSRunningApplication,
                              timeout: TimeInterval,
                              completion: @escaping (_ resolved: Bool) -> Void) {
        let start = Date()
        func tick() {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
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
