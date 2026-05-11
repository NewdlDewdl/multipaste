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
        onLaunchAtLoginChanged: { enabled in LoginAgent.setEnabled(enabled) }
    )
    private lazy var menubar = MenuBarController(
        store: store,
        monitor: monitor,
        prefs: prefs,
        onShowPicker: { [weak self] in self?.picker.show() },
        onPasteItem:  { [weak self] item in self?.pickAndPaste(item) },
        onShowSettings: { [weak self] in self?.settings.show() },
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
