import AppKit
import MultipasteCore

/// Status-bar item and dropdown menu. Holds the only persistent reference
/// to the `NSStatusItem`; if this controller dies the icon disappears.
final class MenuBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let store: HistoryStore
    private let monitor: ClipboardMonitor
    private let prefs: Preferences
    private let onShowPicker: () -> Void
    private let onPasteItem: (ClipboardItem) -> Void
    private let onShowSettings: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onGrantAccessibility: () -> Void
    private let onQuit: () -> Void

    /// Set by AppDelegate via `setAccessibilityState(_:)` whenever the
    /// `PermissionMonitor` observes a change. Drives whether the menu
    /// shows the "Grant Access" banner and dims the status icon.
    private var accessibilityGranted: Bool

    init(store: HistoryStore,
         monitor: ClipboardMonitor,
         prefs: Preferences,
         initialAccessibilityGranted: Bool,
         onShowPicker: @escaping () -> Void,
         onPasteItem: @escaping (ClipboardItem) -> Void,
         onShowSettings: @escaping () -> Void,
         onCheckForUpdates: @escaping () -> Void,
         onGrantAccessibility: @escaping () -> Void,
         onQuit: @escaping () -> Void) {
        self.store = store
        self.monitor = monitor
        self.prefs = prefs
        self.accessibilityGranted = initialAccessibilityGranted
        self.onShowPicker = onShowPicker
        self.onPasteItem = onPasteItem
        self.onShowSettings = onShowSettings
        self.onCheckForUpdates = onCheckForUpdates
        self.onGrantAccessibility = onGrantAccessibility
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        refreshStatusButton()

        let menu = NSMenu()
        menu.delegate = self
        rebuild(menu)
        statusItem.menu = menu
    }

    /// Reapply the status-item icon + tooltip in response to a state
    /// change (currently just the Accessibility-granted bit).
    private func refreshStatusButton() {
        guard let button = statusItem.button else { return }
        if let image = NSImage(systemSymbolName: "doc.on.clipboard",
                               accessibilityDescription: "Multipaste") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "📋"
        }
        // Dim the icon when Accessibility is missing — a subtle "needs
        // attention" signal that survives light/dark mode and won't be
        // mistaken for an outage.
        button.appearsDisabled = !accessibilityGranted
        button.toolTip = accessibilityGranted
            ? "Multipaste — clipboard history (\(hotkeyDisplay))"
            : "Multipaste — Accessibility access not granted yet. Click for setup."
    }

    /// Update the menu in place when the OS reports a permission change.
    func setAccessibilityGranted(_ granted: Bool) {
        guard granted != accessibilityGranted else { return }
        accessibilityGranted = granted
        refreshStatusButton()
        if let m = statusItem.menu { rebuild(m) }
    }

    private var hotkeyDisplay: String {
        let h = prefs.hotkey
        var parts: [String] = []
        if h.modifiers.contains(.control) { parts.append("⌃") }
        if h.modifiers.contains(.option)  { parts.append("⌥") }
        if h.modifiers.contains(.shift)   { parts.append("⇧") }
        if h.modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyLabel(for: h.keyCode))
        return parts.joined()
    }

    private func keyLabel(for keyCode: Int) -> String {
        switch keyCode {
        case 9: return "V"
        case 8: return "C"
        default: return "key-\(keyCode)"
        }
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        // Top "Grant Accessibility" banner — only present when missing.
        if !accessibilityGranted {
            let banner = NSMenuItem(title: "\u{26A0}\u{FE0F}  Grant Accessibility access\u{2026}",
                                    action: #selector(handleGrantAccessibility),
                                    keyEquivalent: "")
            banner.target = self
            banner.toolTip = "Auto-paste and snippet expansion need this. Click for step-by-step."
            menu.addItem(banner)

            let why = NSMenuItem(title: "  Needed for auto-paste and snippets",
                                  action: nil, keyEquivalent: "")
            why.isEnabled = false
            menu.addItem(why)

            menu.addItem(NSMenuItem.separator())
        }

        let open = NSMenuItem(title: "Show Clipboard History  \(hotkeyDisplay)",
                              action: #selector(handleShow),
                              keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        menu.addItem(NSMenuItem.separator())

        let header = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let recent = Array(store.items.prefix(9))
        if recent.isEmpty {
            let empty = NSMenuItem(title: "  (no items yet)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (i, item) in recent.enumerated() {
                let label = "  " + (item.pinned ? "📌 " : "") + truncated(item.preview, to: 60)
                let m = NSMenuItem(title: label,
                                   action: #selector(handleQuickPick(_:)),
                                   keyEquivalent: i < 9 ? "\(i + 1)" : "")
                m.keyEquivalentModifierMask = [.command]
                m.target = self
                m.representedObject = item.id
                menu.addItem(m)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let pause = NSMenuItem(
            title: monitor.paused ? "Resume Monitoring" : "Pause Monitoring",
            action: #selector(handlePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)

        let clear = NSMenuItem(title: "Clear History (Keep Pinned)",
                               action: #selector(handleClear), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        let clearAll = NSMenuItem(title: "Clear All",
                                  action: #selector(handleClearAll), keyEquivalent: "")
        clearAll.target = self
        menu.addItem(clearAll)

        menu.addItem(NSMenuItem.separator())

        let prefs = NSMenuItem(title: "Preferences…",
                                action: #selector(handleShowSettings), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let openFolder = NSMenuItem(title: "Open Data Folder",
                                    action: #selector(handleOpenFolder), keyEquivalent: "")
        openFolder.target = self
        menu.addItem(openFolder)

        let check = NSMenuItem(title: "Check for Updates\u{2026}",
                               action: #selector(handleCheckForUpdates), keyEquivalent: "")
        check.target = self
        menu.addItem(check)

        let about = NSMenuItem(title: "About Multipaste",
                               action: #selector(handleAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit Multipaste",
                              action: #selector(handleQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func truncated(_ s: String, to n: Int) -> String {
        let one = s.replacingOccurrences(of: "\n", with: " ↩ ")
        if one.count > n { return String(one.prefix(n)) + "…" }
        return one
    }

    // MARK: - Actions

    @objc private func handleShow()               { onShowPicker() }
    @objc private func handlePause()              { monitor.paused.toggle() }
    @objc private func handleClear()              { store.clear() }
    @objc private func handleClearAll()           { store.clearAll() }
    @objc private func handleShowSettings()       { onShowSettings() }
    @objc private func handleCheckForUpdates()    { onCheckForUpdates() }
    @objc private func handleGrantAccessibility() { onGrantAccessibility() }
    @objc private func handleQuit()               { onQuit() }

    @objc private func handleOpenFolder() {
        let url = AppPaths.dataDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func handleQuickPick(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = store.items.first(where: { $0.id == id }) else { return }
        onPasteItem(item)
    }

    @objc private func handleAbout() {
        let a = NSAlert()
        a.messageText = "Multipaste \(MultipasteVersion.value)"
        a.informativeText = """
            Clipboard history for macOS.

            • Open with \(hotkeyDisplay)
            • ⌘1–9 to quick-paste recent items
            • ⌘P to pin, ⌘⌫ to delete
            • Pinned items survive history eviction

            Made for Rohin.
            """
        a.runModal()
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) { rebuild(menu) }
}
