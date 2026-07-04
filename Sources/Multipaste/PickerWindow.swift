// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

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
    private let prefs: Preferences
    /// Called with the picked items IN PASTE ORDER (a single-element
    /// array for the classic one-item pick; mark order for multi-pastes),
    /// the app to paste into, and the paste flavor (rich vs plain text; see
    /// `effectiveFlavor`).
    private let onPick: ([ClipboardItem], NSRunningApplication?, PasteFlavor) -> Void
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

    /// Multi-paste marks (⌥↩ / ⌘-click / Space / ⌥⌘A). Keyed by item id
    /// so they survive re-filtering; order is mark order: exactly the
    /// order the items will paste in. Reset on every `show()`.
    private var marks = MarkList<UUID>()

    init(store: HistoryStore,
         prefs: Preferences,
         onPick: @escaping ([ClipboardItem], NSRunningApplication?, PasteFlavor) -> Void,
         onEditTrigger: @escaping (ClipboardItem) -> Void) {
        self.store = store
        self.prefs = prefs
        self.onPick = onPick
        self.onEditTrigger = onEditTrigger

        let rect = NSRect(x: 0, y: 0, width: 540, height: 380)
        panel = PickerPanel(
            contentRect: rect,
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel, .resizable, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Multipaste"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating
        // We no longer activate Multipaste when showing the picker, so the
        // app never "deactivates" in the sense `hidesOnDeactivate` keys off
        // (it was never active). Dismissal on click-away is handled by
        // `windowDidResignKey` instead. Leaving this true would do nothing
        // useful and could hide the panel at surprising moments.
        panel.hidesOnDeactivate = false
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

        hintLabel = NSTextField(labelWithString: "")
        hintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        super.init()

        // Set initial hint text now that `self` is available.
        hintLabel.stringValue = defaultHintText

        searchField.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        // Single click: only meaningful with ⌘ held (toggle a multi-paste
        // mark). A plain click just selects, which the table already did
        // before the action fires.
        tableView.action = #selector(tableClicked)
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

        // Reset query and marks each invocation; surprising otherwise
        // (stale marks from a dismissed picker would silently multi-paste).
        query = ""
        searchField.stringValue = ""
        marks.clear()
        updateMarkHint()
        reload()
        positionOnActiveScreen()
        // Present as a NON-ACTIVATING key panel: order it above everything
        // and take keyboard focus WITHOUT activating Multipaste. Because we
        // never become the active app, `previouslyActiveApp` stays the
        // frontmost application the entire time the picker is open — so on
        // pick we synthesize ⌘V straight into it, with no app-activation
        // round-trip to race against.
        //
        // This is the fix for the v2.1.x "press Enter, nothing pastes,
        // reopen and retry" bug: the old code called
        // `NSApp.activate(ignoringOtherApps:)` here, which forced focus away
        // from the target and required re-activating it on paste — a hand-off
        // that, on macOS 14+ cooperative activation, completed *after* ⌘V was
        // already posted often enough to drop the paste intermittently.
        // (Matches Maccy's FloatingPanel: orderFrontRegardless + makeKey,
        // never NSApp.activate.)
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(searchField)
        if !filtered.isEmpty {
            tableView.selectRowIndexes([0], byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
        Diagnostics.log(
            "picker.show: panelKey=\(panel.isKeyWindow) " +
            "front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?") " +
            "prevApp=\(previouslyActiveApp?.bundleIdentifier ?? "nil")"
        )
    }

    func hide() {
        panel.orderOut(nil)
    }

    // MARK: - NSWindowDelegate

    /// Dismiss the picker when it loses key focus — i.e. the user clicked
    /// into another app or window. This replaces the old
    /// `hidesOnDeactivate` dismissal, which depended on Multipaste being
    /// the active app; now that the picker is a non-activating panel,
    /// Multipaste never activates, so we key off the panel resigning key
    /// instead.
    ///
    /// The `isVisible` guard makes this a no-op for the resignKey that
    /// `hide()`'s own `orderOut` triggers (by then the panel is already
    /// ordered out), so committing a pick doesn't double-hide.
    func windowDidResignKey(_ notification: Notification) {
        guard panel.isVisible else { return }
        Diagnostics.log("picker.resignKey → hide")
        hide()
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

    /// When set, the next `reload()` re-selects the row for this item id
    /// (and scrolls it into view) instead of keeping the stale row index.
    /// Set by pin/unpin so the highlight follows the item as it moves —
    /// you visibly watch it stay near the top on unpin rather than the
    /// selection jumping to whatever else landed at that row.
    private var pendingReselectID: UUID?

    private func reload() {
        // Capture the item under the current selection so we can keep the
        // highlight on it across the reload, unless a pin/unpin explicitly
        // asked us to follow a specific item.
        let preserveID = pendingReselectID
            ?? ((tableView.selectedRow >= 0 && tableView.selectedRow < filtered.count)
                ? filtered[tableView.selectedRow].id : nil)
        pendingReselectID = nil

        filtered = store.search(query)
        // Marks survive filtering (they key on item id, not row), but not
        // deletion/eviction: prune against what actually EXISTS, never
        // against the filtered subset.
        let markCount = marks.count
        marks.prune(keeping: Set(store.items.map(\.id)))
        if marks.count != markCount { updateMarkHint() }
        tableView.reloadData()

        guard !filtered.isEmpty else { return }
        if let id = preserveID, let row = filtered.firstIndex(where: { $0.id == id }) {
            tableView.selectRowIndexes([row], byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
        } else if tableView.selectedRow < 0 || tableView.selectedRow >= filtered.count {
            tableView.selectRowIndexes([0], byExtendingSelection: false)
        }
    }

    /// Briefly replace the hint bar with an action confirmation. The
    /// hint label restores after `duration` seconds. Used by pin /
    /// unpin / delete so the user sees an immediate "yes, I did that"
    /// signal even when the row's visual change isn't dramatic.
    private var hintRestoreTimer: Timer?
    private let defaultHintText = "↑↓ select   ↩ paste   ⇧↩ plain text   ⌥↩ mark   ⌘1–9 quick   ⌘⌫ delete   ⌘P pin   ⌘E snippet   esc close"

    private func flashHint(_ message: String, duration: TimeInterval = 1.6) {
        hintLabel.stringValue = message
        hintLabel.textColor = .controlAccentColor
        hintRestoreTimer?.invalidate()
        hintRestoreTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            // Restore to the mark-aware hint, not blindly to the default;
            // a pin/delete flash mid-marking shouldn't erase the "N marked"
            // status line.
            self?.updateMarkHint()
        }
    }

    /// The persistent (non-flash) state of the hint bar: the default key
    /// legend when nothing is marked, or a live "N marked" status while
    /// a multi-paste is being assembled.
    private func updateMarkHint() {
        hintRestoreTimer?.invalidate()
        if marks.isEmpty {
            hintLabel.stringValue = defaultHintText
            hintLabel.textColor = .secondaryLabelColor
        } else {
            let n = marks.count
            hintLabel.stringValue =
                "\(n) marked · ↩ pastes all \(n) in badge order   ⌥↩/⌘-click mark   ⌥⌘A all   esc clear"
            hintLabel.textColor = .controlAccentColor
        }
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        ItemCellView(item: filtered[row], index: row,
                     markIndex: marks.position(of: filtered[row].id))
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        query = searchField.stringValue
        reload()
    }

    // MARK: - Keyboard

    private func handleKey(_ ev: NSEvent) -> Bool {
        let isCmd = ev.modifierFlags.contains(.command)
        let isShift = ev.modifierFlags.contains(.shift)
        let isOption = ev.modifierFlags.contains(.option)
        let chars = ev.charactersIgnoringModifiers ?? ""

        switch ev.keyCode {
        case 53: // esc: two-stage when marking: first clear marks, then close
            if !marks.isEmpty {
                clearMarksAndRedraw()
                flashHint("Marks cleared; esc again closes")
            } else {
                hide()
            }
            return true
        case 36, 76: // return / enter (⌥↩ = mark + step down, ⇧↩ = paste plain text)
            if isOption {
                toggleMarkOnSelection(advance: true)
            } else {
                commit(flavor: effectiveFlavor(shiftPressed: isShift))
            }
            return true
        case 48: // tab
            handleTab(reverse: isShift); return true
        case 49: // space: mark, but ONLY when the list (not search) has
                 // focus; in the search field a space is just typing.
            if case .row = currentFocusedRegion() {
                toggleMarkOnSelection(advance: true)
                return true
            }
            return false
        case 125: // arrow down
            moveSelection(by: 1); return true
        case 126: // arrow up
            moveSelection(by: -1); return true
        default:
            break
        }

        // ⌥⌘A: mark all visible / unmark all visible. Checked before the
        // other ⌘-chords; plain ⌘A still reaches the search field's
        // select-all untouched.
        if isCmd && isOption && chars.lowercased() == "a" {
            toggleMarkAllVisible()
            return true
        }
        if isCmd, let digit = Int(chars), digit >= 1 && digit <= 9 {
            let idx = digit - 1
            if idx < filtered.count {
                // ⌘1-9 quick-pick pastes in the user's default flavor;
                // Shift is reserved for the ⇧↩ path.
                commitItems([filtered[idx]], flavor: effectiveFlavor(shiftPressed: false))
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

    /// The paste flavor for a pick. Thin forwarder to the pure, unit-tested
    /// `PasteFlavor.effective` policy (base = the user's default, `⇧`
    /// inverts) — the decision itself lives in `MultipasteCore` so all four
    /// pref × Shift combinations are locked by tests.
    private func effectiveFlavor(shiftPressed: Bool) -> PasteFlavor {
        PasteFlavor.effective(plainTextPasteDefault: prefs.plainTextPasteDefault,
                              shiftPressed: shiftPressed)
    }

    /// Double-click on a row. Honors a held Shift as the plain/rich inverter,
    /// matching the ⇧↩ keyboard path.
    @objc private func commitSelection() {
        let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
        commit(flavor: effectiveFlavor(shiftPressed: shift))
    }

    /// ↩ / ⇧↩ / double-click. With marks: paste ALL marked items in badge
    /// order. Without: classic single paste of the highlighted row. `flavor`
    /// applies to every item in the pick.
    private func commit(flavor: PasteFlavor) {
        if !marks.isEmpty {
            // Resolve mark ids → items against the full store, not the
            // filtered view; marked items may be filtered out right now
            // and must still paste.
            let byID = Dictionary(uniqueKeysWithValues: store.items.map { ($0.id, $0) })
            let chosen = marks.ids.compactMap { byID[$0] }
            guard !chosen.isEmpty else {
                clearMarksAndRedraw()
                return
            }
            commitItems(chosen, flavor: flavor)
            return
        }
        let row = tableView.selectedRow
        guard row >= 0 && row < filtered.count else { return }
        commitItems([filtered[row]], flavor: flavor)
    }

    /// Common exit path for return-on-selection, multi-paste, AND ⌘1-9
    /// quick pick: hide panel, snapshot the target app, fire onPick with the
    /// chosen flavor. The AppDelegate owns routing + ⌘V synthesis from here.
    private func commitItems(_ items: [ClipboardItem], flavor: PasteFlavor) {
        let target = previouslyActiveApp
        hide()
        onPick(items, target, flavor)
    }

    // MARK: - Multi-paste marks

    /// ⌘-click toggles a mark on the clicked row. Plain clicks fall
    /// through (the table's own machinery already moved the selection).
    @objc private func tableClicked() {
        guard NSApp.currentEvent?.modifierFlags.contains(.command) == true else { return }
        let row = tableView.clickedRow
        guard row >= 0 && row < filtered.count else { return }
        marks.toggle(filtered[row].id)
        redrawMarks(preservingSelectionAt: row)
        updateMarkHint()
    }

    private func toggleMarkOnSelection(advance: Bool) {
        let row = tableView.selectedRow
        guard row >= 0 && row < filtered.count else { return }
        marks.toggle(filtered[row].id)
        redrawMarks(preservingSelectionAt: row)
        if advance { moveSelection(by: 1) }
        updateMarkHint()
    }

    private func toggleMarkAllVisible() {
        guard !filtered.isEmpty else { return }
        let row = tableView.selectedRow
        marks.toggleAll(filtered.map(\.id))
        redrawMarks(preservingSelectionAt: row)
        updateMarkHint()
    }

    private func clearMarksAndRedraw() {
        let row = tableView.selectedRow
        marks.clear()
        redrawMarks(preservingSelectionAt: row)
        updateMarkHint()
    }

    /// Rebuild every visible cell (badge numbers shift globally when a
    /// mark in the middle is removed) without losing the highlight.
    private func redrawMarks(preservingSelectionAt row: Int) {
        tableView.reloadData()
        if row >= 0 && row < filtered.count {
            tableView.selectRowIndexes([row], byExtendingSelection: false)
        }
    }

    private func moveSelection(by delta: Int) {
        guard !filtered.isEmpty else { return }
        let cur = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        let next = max(0, min(filtered.count - 1, cur + delta))
        tableView.selectRowIndexes([next], byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    /// Compute the current logical focus position. The search field's
    /// "first responder" is actually its field editor (the NSTextView
    /// AppKit substitutes for typing), so we compare against either.
    private func currentFocusedRegion() -> FocusedRegion {
        if panel.firstResponder === searchField ||
            (searchField.currentEditor() != nil &&
             panel.firstResponder === searchField.currentEditor()) {
            return .searchField
        }
        if panel.firstResponder === tableView {
            let row = tableView.selectedRow
            return row >= 0 ? .row(row) : .searchField
        }
        // Anything else (rare) — treat as search to keep behavior sane.
        return .searchField
    }

    /// Apply a logical focus position to the actual AppKit state:
    /// transfer first-responder, adjust table selection.
    private func applyFocus(_ region: FocusedRegion) {
        switch region {
        case .searchField:
            panel.makeFirstResponder(searchField)
            // Move the caret to the end of the existing query so the
            // user can keep typing without re-positioning.
            if let editor = searchField.currentEditor() as? NSTextView {
                let len = (searchField.stringValue as NSString).length
                editor.selectedRange = NSRange(location: len, length: 0)
            }
        case .row(let i):
            panel.makeFirstResponder(tableView)
            tableView.selectRowIndexes([i], byExtendingSelection: false)
            tableView.scrollRowToVisible(i)
        }
    }

    /// Tab navigation, both forward and reverse.
    private func handleTab(reverse: Bool) {
        let here = currentFocusedRegion()
        let total = filtered.count
        let next = reverse
            ? TabNavigation.previous(from: here, totalRows: total)
            : TabNavigation.next(from: here, totalRows: total)
        applyFocus(next)
    }

    private func togglePinSelection() {
        let row = tableView.selectedRow
        guard row >= 0 && row < filtered.count else { return }
        let item = filtered[row]
        let willBePinned = !item.pinned
        // Keep the highlight on this exact item after the list reorders,
        // so the user watches it stay near the top on unpin (rather than
        // the selection jumping to whatever else lands at this row).
        pendingReselectID = item.id
        store.togglePin(id: item.id)
        let preview = item.preview.replacingOccurrences(of: "\n", with: " ")
            .prefix(48)
        flashHint(willBePinned
            ? "📌 Pinned — survives history eviction and snippet expansion"
            : "Unpinned “\(preview)” — stays here, won’t drop back down")
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
        let item = filtered[row]
        store.remove(id: item.id)
        let preview = item.preview.replacingOccurrences(of: "\n", with: " ")
            .prefix(48)
        flashHint("Deleted “\(preview)”")
    }
}

// MARK: - Cell

private final class ItemCellView: NSView {

    /// `markIndex` is the item's 1-based position in the multi-paste
    /// order (nil = unmarked). Rendered as a filled accent badge so the
    /// row visibly answers both "is this in the paste?" and "when?".
    init(item: ClipboardItem, index: Int, markIndex: Int? = nil) {
        super.init(frame: .zero)

        // Pinned-row visual upgrade (v1.9.0): a chunky colored left
        // accent stripe + subtle background tint. Pinning was previously
        // signaled only by a tiny 📌 emoji at the right edge of the
        // cell — easy to miss, leading to "did pin even do anything?"
        // confusion. Now the entire row visibly says "pinned."
        if item.pinned {
            wantsLayer = true
            layer?.backgroundColor = NSColor.systemYellow
                .withAlphaComponent(0.10).cgColor
            layer?.cornerRadius = 4

            let accent = NSView()
            accent.wantsLayer = true
            accent.layer?.backgroundColor = NSColor.systemYellow.cgColor
            accent.layer?.cornerRadius = 1.5
            accent.translatesAutoresizingMaskIntoConstraints = false
            addSubview(accent)
            NSLayoutConstraint.activate([
                accent.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
                accent.topAnchor.constraint(equalTo: topAnchor, constant: 6),
                accent.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
                accent.widthAnchor.constraint(equalToConstant: 3),
            ])
        }

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

        let pin = NSTextField(labelWithString: item.pinned ? "📌 PINNED" : "")
        pin.font = item.pinned
            ? .systemFont(ofSize: 9, weight: .heavy)
            : .systemFont(ofSize: 12)
        pin.textColor = item.pinned ? .systemYellow : .secondaryLabelColor

        // Image thumbnail (only present for .image kind)
        let thumbnailView: NSImageView? = {
            guard let thumb = ThumbnailCache.shared.thumbnail(for: item, edge: 32) else { return nil }
            let iv = NSImageView()
            iv.image = thumb
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.imageFrameStyle = .grayBezel
            return iv
        }()

        // Multi-paste order badge: a filled accent capsule with the
        // item's 1-based paste position. Lives just left of the kind
        // label so it reads as row *status*, like the pin marker.
        let markBadge: NSTextField? = {
            guard let n = markIndex else { return nil }
            let lbl = NSTextField(labelWithString: " \(n) ")
            lbl.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
            lbl.textColor = .white
            lbl.alignment = .center
            lbl.wantsLayer = true
            lbl.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            lbl.layer?.cornerRadius = 7
            lbl.layer?.masksToBounds = true
            lbl.toolTip = "Pastes \(ordinal(n)); ↩ pastes all marked items"
            return lbl
        }()

        var allViews: [NSView] = [badge, kind, preview, pin]
        if let lbl = triggerLabel { allViews.append(lbl) }
        if let tv = thumbnailView { allViews.append(tv) }
        if let mb = markBadge { allViews.append(mb) }
        for v in allViews {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        // Layout: [badge | thumbnail?(32) | preview | trigger? | mark? | kind | pin]
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

        // Trailing cluster chains right-to-left: pin ← kind ← mark? ← trigger?
        let leftOfKind: NSLayoutXAxisAnchor
        if let mb = markBadge {
            NSLayoutConstraint.activate([
                mb.trailingAnchor.constraint(equalTo: kind.leadingAnchor, constant: -8),
                mb.centerYAnchor.constraint(equalTo: centerYAnchor),
                mb.heightAnchor.constraint(equalToConstant: 14),
                mb.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            ])
            leftOfKind = mb.leadingAnchor
        } else {
            leftOfKind = kind.leadingAnchor
        }

        let trailingOfPreview: NSLayoutXAxisAnchor
        if let lbl = triggerLabel {
            NSLayoutConstraint.activate([
                lbl.trailingAnchor.constraint(equalTo: leftOfKind, constant: -8),
                lbl.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
            trailingOfPreview = lbl.leadingAnchor
        } else {
            trailingOfPreview = leftOfKind
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

    /// "1st" / "2nd" / "3rd" / "11th": for the mark badge tooltip.
    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1):       suffix = "st"
        case (_, 2):       suffix = "nd"
        case (_, 3):       suffix = "rd"
        default:           suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

// MARK: - Panel

/// `NSPanel` subclass whose entire job is to answer `canBecomeKey == true`.
///
/// A `.nonactivatingPanel` is *permitted* to hold keyboard focus while its
/// owning app stays inactive — but AppKit still routes typing to it only if
/// the window reports that it can become key. The default for a panel that
/// isn't activating its app can be `false`, which would leave the search
/// field unable to receive input unless we activate Multipaste… and
/// activating Multipaste is precisely the focus-handoff race this panel
/// exists to avoid. So we say "yes, I can be key" explicitly while never
/// becoming `main` (we're an accessory app, not a document app).
///
/// Matches Maccy's `FloatingPanel`. Per the AppKit docs the nonactivating
/// behavior is fixed at init time, so the style mask must be set in the
/// initializer (it is) and never mutated afterward.
final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
