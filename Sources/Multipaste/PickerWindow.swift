import AppKit
import MultipasteCore

/// Floating picker invoked by the global hotkey. Uses a non-activating
/// `NSPanel` so opening it doesn't yank focus away from the target app
/// (this matters: when the user picks an item we synthesize ⌘V back into
/// whatever app was foreground a moment ago).
final class PickerWindow: NSObject, NSWindowDelegate,
                          NSTableViewDataSource, NSTableViewDelegate,
                          NSSearchFieldDelegate {

    private let store: HistoryStore
    private let onPick: (ClipboardItem, NSRunningApplication?) -> Void
    private let onEditTrigger: (ClipboardItem) -> Void

    /// The app that was frontmost when the picker opened. We re-activate
    /// it before pasting so the synthesized ⌘V lands in *that* app rather
    /// than in Multipaste itself. macOS routes synthesized key events to
    /// whatever's currently frontmost; if the picker's dismissal hadn't
    /// finished switching focus back by the time we posted ⌘V, the
    /// keystroke disappeared into Multipaste's own event queue. v1.7.0
    /// and earlier had this bug — picks landed on the clipboard but
    /// didn't auto-paste; users had to ⌘V manually after.
    private var previouslyActiveApp: NSRunningApplication?

    private let panel: NSPanel
    private let searchField: NSSearchField
    private let scrollView: NSScrollView
    private let tableView: NSTableView
    private let hintLabel: NSTextField

    private var filtered: [ClipboardItem] = []
    private var query: String = ""
    private var storeToken: HistoryStore.Token?
    private var keyMonitor: Any?

    init(store: HistoryStore,
         onPick: @escaping (ClipboardItem, NSRunningApplication?) -> Void,
         onEditTrigger: @escaping (ClipboardItem) -> Void) {
        self.store = store
        self.onPick = onPick
        self.onEditTrigger = onEditTrigger

        let rect = NSRect(x: 0, y: 0, width: 540, height: 380)
        panel = NSPanel(
            contentRect: rect,
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel, .resizable, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Multipaste"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]

        searchField = NSSearchField()
        searchField.placeholderString = "Search clipboard…"
        searchField.font = .systemFont(ofSize: 14)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.focusRingType = .none

        tableView = NSTableView()
        tableView.allowsMultipleSelection = false
        tableView.headerView = nil
        tableView.rowHeight = 48
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.style = .inset
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        col.width = 500
        col.resizingMask = [.autoresizingMask]
        tableView.addTableColumn(col)

        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder

        hintLabel = NSTextField(labelWithString: "↑↓ select   ↩ paste   ⌘1–9 quick-pick   ⌘⌫ delete   ⌘P pin   ⌘E snippet   esc close")
        hintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        super.init()

        searchField.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(commitSelection)
        panel.delegate = self

        let content = NSView()
        content.addSubview(searchField)
        content.addSubview(scrollView)
        content.addSubview(hintLabel)
        panel.contentView = content

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),

            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -6),

            hintLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            hintLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
        ])

        // Local key monitor — only fires when our panel is key. We intercept
        // navigation keys here so the search field doesn't eat them.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            guard let self = self, self.panel.isKeyWindow else { return ev }
            return self.handleKey(ev) ? nil : ev
        }

        storeToken = store.subscribe { [weak self] _ in
            DispatchQueue.main.async { self?.reload() }
        }
        reload()
    }

    deinit {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        if let t = storeToken { store.unsubscribe(t) }
    }

    // MARK: - Public

    /// Display the picker. Positions on the active screen and pre-selects
    /// the most-recent item. Captures the previously-active app FIRST so
    /// we can return focus to it on pick.
    func show() {
        // Capture this BEFORE NSApp.activate — once we activate ourselves,
        // frontmostApplication becomes us.
        let mePID = ProcessInfo.processInfo.processIdentifier
        let front = NSWorkspace.shared.frontmostApplication
        if let f = front, f.processIdentifier != mePID {
            previouslyActiveApp = f
        }

        // Reset query each invocation — surprising otherwise
        query = ""
        searchField.stringValue = ""
        reload()
        positionOnActiveScreen()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(searchField)
        if !filtered.isEmpty {
            tableView.selectRowIndexes([0], byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    // MARK: - Layout

    private func positionOnActiveScreen() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let s = screen else { return }
        let frame = panel.frame
        let visible = s.visibleFrame
        let x = visible.midX - frame.width / 2
        // Slightly above center reads more like "above the focus point".
        let y = visible.midY - frame.height / 2 + visible.height * 0.10
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func reload() {
        filtered = store.search(query)
        tableView.reloadData()
        if filtered.isEmpty {
            // nothing to select
        } else if tableView.selectedRow < 0 || tableView.selectedRow >= filtered.count {
            tableView.selectRowIndexes([0], byExtendingSelection: false)
        }
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        ItemCellView(item: filtered[row], index: row)
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        query = searchField.stringValue
        reload()
    }

    // MARK: - Keyboard

    private func handleKey(_ ev: NSEvent) -> Bool {
        let isCmd = ev.modifierFlags.contains(.command)
        let chars = ev.charactersIgnoringModifiers ?? ""

        switch ev.keyCode {
        case 53: // esc
            hide(); return true
        case 36, 76: // return / enter
            commitSelection(); return true
        case 125: // arrow down
            moveSelection(by: 1); return true
        case 126: // arrow up
            moveSelection(by: -1); return true
        default:
            break
        }

        if isCmd, let digit = Int(chars), digit >= 1 && digit <= 9 {
            let idx = digit - 1
            if idx < filtered.count {
                commitItem(filtered[idx])
            }
            return true
        }
        if isCmd && chars.lowercased() == "p" {
            togglePinSelection(); return true
        }
        if isCmd && chars.lowercased() == "e" {
            editTriggerOnSelection(); return true
        }
        if isCmd && chars.lowercased() == "backspace" {
            // unreachable — kept symmetric
            return false
        }
        // ⌘⌫ deletes selected (so plain backspace still edits search)
        if isCmd && ev.keyCode == 51 {
            deleteSelected(); return true
        }
        return false
    }

    @objc private func commitSelection() {
        let row = tableView.selectedRow
        guard row >= 0 && row < filtered.count else { return }
        let item = filtered[row]
        commitItem(item)
    }

    /// Common path for return-on-selection AND ⌘1-9 quick pick: hide
    /// panel, snapshot the target app, fire onPick with it. The AppDelegate
    /// is responsible for re-activating the app and polling for focus
    /// before synthesizing ⌘V.
    private func commitItem(_ item: ClipboardItem) {
        let target = previouslyActiveApp
        hide()
        onPick(item, target)
    }

    private func moveSelection(by delta: Int) {
        guard !filtered.isEmpty else { return }
        let cur = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        let next = max(0, min(filtered.count - 1, cur + delta))
        tableView.selectRowIndexes([next], byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func togglePinSelection() {
        let row = tableView.selectedRow
        guard row >= 0 && row < filtered.count else { return }
        store.togglePin(id: filtered[row].id)
    }

    private func editTriggerOnSelection() {
        let row = tableView.selectedRow
        guard row >= 0 && row < filtered.count else { return }
        let item = filtered[row]
        hide()
        onEditTrigger(item)
    }

    private func deleteSelected() {
        let row = tableView.selectedRow
        guard row >= 0 && row < filtered.count else { return }
        store.remove(id: filtered[row].id)
    }
}

// MARK: - Cell

private final class ItemCellView: NSView {

    init(item: ClipboardItem, index: Int) {
        super.init(frame: .zero)

        let badge = NSTextField(labelWithString: index < 9 ? "⌘\(index + 1)" : "")
        badge.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        badge.textColor = .tertiaryLabelColor
        badge.alignment = .left

        let kind = NSTextField(labelWithString: item.kindLabel.uppercased())
        kind.font = .systemFont(ofSize: 9, weight: .semibold)
        kind.textColor = .secondaryLabelColor

        let triggerLabel: NSTextField? = {
            guard let t = item.trigger, !t.isEmpty else { return nil }
            let lbl = NSTextField(labelWithString: "⌨ \(t)")
            lbl.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
            lbl.textColor = .systemBlue
            return lbl
        }()

        // Collapse newlines for table display, keep raw text for tooltip
        let collapsed = item.preview.replacingOccurrences(of: "\n", with: " ↩ ")
        let preview = NSTextField(labelWithString: collapsed)
        preview.font = .systemFont(ofSize: 13)
        preview.lineBreakMode = .byTruncatingTail
        preview.maximumNumberOfLines = 2
        preview.toolTip = item.preview

        let pin = NSTextField(labelWithString: item.pinned ? "📌" : "")
        pin.font = .systemFont(ofSize: 12)

        // Image thumbnail (only present for .image kind)
        let thumbnailView: NSImageView? = {
            guard let thumb = ThumbnailCache.shared.thumbnail(for: item, edge: 32) else { return nil }
            let iv = NSImageView()
            iv.image = thumb
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.imageFrameStyle = .grayBezel
            return iv
        }()

        var allViews: [NSView] = [badge, kind, preview, pin]
        if let lbl = triggerLabel { allViews.append(lbl) }
        if let tv = thumbnailView { allViews.append(tv) }
        for v in allViews {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        // Layout: [badge | thumbnail?(32) | preview | trigger? | kind | pin]
        let previewLeading: NSLayoutXAxisAnchor
        if let tv = thumbnailView {
            NSLayoutConstraint.activate([
                tv.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 6),
                tv.centerYAnchor.constraint(equalTo: centerYAnchor),
                tv.widthAnchor.constraint(equalToConstant: 32),
                tv.heightAnchor.constraint(equalToConstant: 32),
            ])
            previewLeading = tv.trailingAnchor
        } else {
            previewLeading = badge.trailingAnchor
        }

        let trailingOfPreview: NSLayoutXAxisAnchor
        if let lbl = triggerLabel {
            NSLayoutConstraint.activate([
                lbl.trailingAnchor.constraint(equalTo: kind.leadingAnchor, constant: -8),
                lbl.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            trailingOfPreview = lbl.leadingAnchor
        } else {
            trailingOfPreview = kind.leadingAnchor
        }

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 30),

            preview.leadingAnchor.constraint(equalTo: previewLeading, constant: 8),
            preview.trailingAnchor.constraint(equalTo: trailingOfPreview, constant: -8),
            preview.centerYAnchor.constraint(equalTo: centerYAnchor),

            kind.trailingAnchor.constraint(equalTo: pin.leadingAnchor, constant: -8),
            kind.centerYAnchor.constraint(equalTo: centerYAnchor),

            pin.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            pin.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}
