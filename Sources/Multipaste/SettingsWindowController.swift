import AppKit
import MultipasteCore

/// Single-window settings UI with three tabs: General, Snippets, About.
/// Re-opens the same window across invocations (cheap; we instantiate
/// once in the AppDelegate and call `show()`).
final class SettingsWindowController: NSObject, NSWindowDelegate {

    private let prefs: Preferences
    private let store: HistoryStore
    private let onHotkeyChanged: (Hotkey) -> Void
    private let onLaunchAtLoginChanged: (Bool) -> Void

    private var window: NSWindow!
    private var storeToken: HistoryStore.Token?

    init(prefs: Preferences,
         store: HistoryStore,
         onHotkeyChanged: @escaping (Hotkey) -> Void,
         onLaunchAtLoginChanged: @escaping (Bool) -> Void) {
        self.prefs = prefs
        self.store = store
        self.onHotkeyChanged = onHotkeyChanged
        self.onLaunchAtLoginChanged = onLaunchAtLoginChanged
        super.init()
        buildWindow()
    }

    func show() {
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        w.title = "Multipaste Preferences"
        w.isReleasedWhenClosed = false
        w.delegate = self

        let tabs = NSTabView()
        tabs.translatesAutoresizingMaskIntoConstraints = false

        let general = NSTabViewItem()
        general.label = "General"
        general.view = makeGeneralTab()
        tabs.addTabViewItem(general)

        let snippets = NSTabViewItem()
        snippets.label = "Snippets"
        snippets.view = makeSnippetsTab()
        tabs.addTabViewItem(snippets)

        let about = NSTabViewItem()
        about.label = "About"
        about.view = makeAboutTab()
        tabs.addTabViewItem(about)

        let content = NSView()
        content.addSubview(tabs)
        NSLayoutConstraint.activate([
            tabs.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            tabs.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            tabs.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            tabs.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
        w.contentView = content
        self.window = w

        // Refresh snippet list when history changes
        storeToken = store.subscribe { [weak self] _ in
            DispatchQueue.main.async { self?.reloadSnippets() }
        }
    }

    // MARK: - General tab

    private var hotkeyField: HotkeyRecorderField!
    private var pasteOnSelectCheckbox: NSButton!
    private var launchAtLoginCheckbox: NSButton!
    private var augmentFileCopiesCheckbox: NSButton!
    private var pinnedFirstCheckbox: NSButton!
    private var maxHistoryField: NSTextField!
    private var maxHistoryStepper: NSStepper!

    private func makeGeneralTab() -> NSView {
        let v = NSView()

        let hkLabel = NSTextField(labelWithString: "Hotkey:")
        let hkField = HotkeyRecorderField(initial: prefs.hotkey)
        hkField.onCapture = { [weak self] hk in
            self?.prefs.hotkey = hk
            self?.onHotkeyChanged(hk)
        }
        self.hotkeyField = hkField

        let hkHint = NSTextField(labelWithString: "Click and press a key combo with at least one modifier.")
        hkHint.font = .systemFont(ofSize: 11)
        hkHint.textColor = .secondaryLabelColor

        let pasteCB = NSButton(checkboxWithTitle: "Auto-paste into focused app after selecting",
                               target: self, action: #selector(togglePasteOnSelect))
        pasteCB.state = prefs.pasteOnSelect ? .on : .off
        self.pasteOnSelectCheckbox = pasteCB

        let launchCB = NSButton(checkboxWithTitle: "Start Multipaste at login",
                                target: self, action: #selector(toggleLaunchAtLogin))
        launchCB.state = prefs.launchAtLogin ? .on : .off
        self.launchAtLoginCheckbox = launchCB

        let augmentCB = NSButton(checkboxWithTitle: "Add file path as text on file copies",
                                 target: self, action: #selector(toggleAugmentFileCopies))
        augmentCB.state = prefs.augmentFileCopiesWithPath ? .on : .off
        augmentCB.toolTip = "When you copy a file in Finder, Multipaste injects the full path as a plain-text representation so pasting in code editors gives you the path while pasting in chat composers still uploads the file."
        self.augmentFileCopiesCheckbox = augmentCB

        let pinnedCB = NSButton(checkboxWithTitle: "Show pinned items at the top of the picker",
                                target: self, action: #selector(togglePinnedFirst))
        pinnedCB.state = prefs.pinnedItemsFirst ? .on : .off
        pinnedCB.toolTip = "Hoist pinned items above unpinned ones (preserving relative recency). Default off — use pinning as a permanent-shelf affordance."
        self.pinnedFirstCheckbox = pinnedCB

        let mhLabel = NSTextField(labelWithString: "History size:")
        let mhField = NSTextField()
        mhField.stringValue = "\(prefs.maxHistory)"
        mhField.alignment = .right
        mhField.target = self
        mhField.action = #selector(maxHistoryChanged)
        self.maxHistoryField = mhField
        let mhStepper = NSStepper()
        mhStepper.minValue = Double(Preferences.minHistory)
        mhStepper.maxValue = Double(Preferences.maxAllowedHistory)
        mhStepper.increment = 10
        mhStepper.integerValue = prefs.maxHistory
        mhStepper.target = self
        mhStepper.action = #selector(maxHistoryStepperChanged)
        self.maxHistoryStepper = mhStepper

        let mhHint = NSTextField(labelWithString: "Pinned items never count against this cap.")
        mhHint.font = .systemFont(ofSize: 11)
        mhHint.textColor = .secondaryLabelColor

        let augmentHint = NSTextField(labelWithString:
            "Code editors paste the path; chat composers paste the file.")
        augmentHint.font = .systemFont(ofSize: 11)
        augmentHint.textColor = .secondaryLabelColor

        let rows: [NSView] = [
            row(hkLabel, hkField, hkHint),
            row(NSView(), pasteCB),
            row(NSView(), launchCB),
            row(NSView(), augmentCB),
            row(NSView(), augmentHint),
            row(NSView(), pinnedCB),
            row(mhLabel, mhField, mhStepper, mhHint),
        ]
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            stack.topAnchor.constraint(equalTo: v.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: v.bottomAnchor),

            mhField.widthAnchor.constraint(equalToConstant: 70),
        ])
        return v
    }

    private func row(_ views: NSView...) -> NSView {
        let h = NSStackView(views: views)
        h.orientation = .horizontal
        h.alignment = .firstBaseline
        h.spacing = 8
        return h
    }

    @objc private func togglePasteOnSelect() {
        prefs.pasteOnSelect = (pasteOnSelectCheckbox.state == .on)
    }

    @objc private func toggleAugmentFileCopies() {
        prefs.augmentFileCopiesWithPath = (augmentFileCopiesCheckbox.state == .on)
    }

    @objc private func togglePinnedFirst() {
        prefs.pinnedItemsFirst = (pinnedFirstCheckbox.state == .on)
    }

    @objc private func toggleLaunchAtLogin() {
        let on = (launchAtLoginCheckbox.state == .on)
        prefs.launchAtLogin = on
        onLaunchAtLoginChanged(on)
    }

    @objc private func maxHistoryChanged() {
        if let v = Int(maxHistoryField.stringValue) {
            prefs.maxHistory = v
            maxHistoryField.integerValue = prefs.maxHistory
            maxHistoryStepper.integerValue = prefs.maxHistory
        }
    }

    @objc private func maxHistoryStepperChanged() {
        prefs.maxHistory = maxHistoryStepper.integerValue
        maxHistoryField.integerValue = prefs.maxHistory
    }

    // MARK: - Snippets tab

    private var snippetTable: NSTableView!
    private var snippets: [ClipboardItem] = []

    private func makeSnippetsTab() -> NSView {
        let v = NSView()

        let table = NSTableView()
        table.headerView = NSTableHeaderView()
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = false
        table.style = .plain

        let triggerCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("trigger"))
        triggerCol.title = "Trigger"
        triggerCol.width = 110
        let previewCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("preview"))
        previewCol.title = "Snippet"
        previewCol.width = 340
        table.addTableColumn(triggerCol)
        table.addTableColumn(previewCol)
        table.dataSource = self
        table.delegate = self
        self.snippetTable = table

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let editBtn = NSButton(title: "Edit Trigger…", target: self, action: #selector(editSelectedSnippet))
        let removeBtn = NSButton(title: "Remove Trigger", target: self, action: #selector(removeSelectedSnippetTrigger))
        let bts = NSStackView(views: [editBtn, removeBtn])
        bts.orientation = .horizontal
        bts.spacing = 8
        bts.translatesAutoresizingMaskIntoConstraints = false

        let hint = NSTextField(labelWithString:
            "Type a trigger followed by space, tab, or return to expand it anywhere.\n" +
            "Add new triggers via the picker (⌘E on a selected item).")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.usesSingleLineMode = false
        hint.lineBreakMode = .byWordWrapping

        v.addSubview(scroll)
        v.addSubview(bts)
        v.addSubview(hint)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: v.topAnchor, constant: 12),

            bts.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            bts.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8),

            hint.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            hint.topAnchor.constraint(equalTo: bts.bottomAnchor, constant: 8),
            hint.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -12),

            scroll.bottomAnchor.constraint(equalTo: bts.topAnchor, constant: -8),
        ])

        reloadSnippets()
        return v
    }

    private func reloadSnippets() {
        snippets = store.snippets
        snippetTable?.reloadData()
    }

    @objc private func editSelectedSnippet() {
        guard let item = currentSnippet() else { return }
        SnippetEditor.prompt(initial: item.trigger ?? "",
                             previewText: item.preview) { [weak self] newTrigger in
            guard let self = self else { return }
            self.store.setTrigger(id: item.id, trigger: newTrigger?.isEmpty == false ? newTrigger : nil)
        }
    }

    @objc private func removeSelectedSnippetTrigger() {
        guard let item = currentSnippet() else { return }
        store.setTrigger(id: item.id, trigger: nil)
    }

    private func currentSnippet() -> ClipboardItem? {
        let row = snippetTable.selectedRow
        guard row >= 0 && row < snippets.count else { return nil }
        return snippets[row]
    }

    // MARK: - About tab

    private func makeAboutTab() -> NSView {
        let v = NSView()
        let title = NSTextField(labelWithString: "Multipaste")
        title.font = .systemFont(ofSize: 28, weight: .bold)
        let ver = NSTextField(labelWithString: "Version \(MultipasteVersion.value)")
        ver.font = .systemFont(ofSize: 13)
        ver.textColor = .secondaryLabelColor
        let body = NSTextField(wrappingLabelWithString: """
            Clipboard history + snippet expansion for macOS.

            • Hotkey opens the picker — keyboard-only operation.
            • Pinned items survive history eviction.
            • Trigger any pinned item with a custom string (e.g. ;addr).
            • Honors org.nspasteboard.* privacy markers — password
              managers are excluded automatically.

            Made for Rohin.  MIT licensed.
            """)
        body.font = .systemFont(ofSize: 12)
        body.textColor = .labelColor
        let stack = NSStackView(views: [title, ver, body])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: v.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            stack.topAnchor.constraint(equalTo: v.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: v.bottomAnchor),
        ])
        return v
    }
}

// MARK: - NSTableView for snippets

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { snippets.count }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let item = snippets[row]
        let text: String
        switch tableColumn?.identifier.rawValue {
        case "trigger": text = item.trigger ?? ""
        case "preview": text = item.preview.replacingOccurrences(of: "\n", with: " ↩ ")
        default: text = ""
        }
        let cell = NSTextField(labelWithString: text)
        cell.lineBreakMode = .byTruncatingTail
        if tableColumn?.identifier.rawValue == "trigger" {
            cell.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            cell.textColor = .systemBlue
        }
        return cell
    }
}

// MARK: - Snippet editor modal

enum SnippetEditor {
    /// Shows a small modal prompt for setting/editing a trigger.
    /// Calls `completion` with the (possibly-empty) new trigger, or with nil
    /// if the user cancelled.
    static func prompt(initial: String, previewText: String,
                       completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Set snippet trigger"
        alert.informativeText = "Typing this trigger followed by space/tab/return will paste:\n\n\(previewText.prefix(120))"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = ";addr"
        field.stringValue = initial
        field.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            completion(field.stringValue)
        } else {
            completion(nil)
        }
    }
}
