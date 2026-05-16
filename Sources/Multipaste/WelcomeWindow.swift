// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import AppKit
import MultipasteCore

/// First-run onboarding window. Shown once after install — explains the
/// hotkey, offers a one-click Accessibility-permission opener, and toggles
/// "start at login" via `SMAppService.mainApp`.
///
/// Why a custom window instead of a sheet on the preferences pane: the
/// preferences window is a settings UI, this is a tutorial. Different
/// jobs, different presentations.
final class WelcomeWindow: NSObject, NSWindowDelegate {

    private let prefs: Preferences
    private let onDone: () -> Void

    private var window: NSWindow!
    private var loginItemSummary: NSTextField!
    private var accessibilitySummary: NSTextField!

    init(prefs: Preferences, onDone: @escaping () -> Void) {
        self.prefs = prefs
        self.onDone = onDone
        super.init()
        buildWindow()
    }

    func show() {
        refreshSummaries()
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "Welcome to Multipaste"
        w.isReleasedWhenClosed = false
        w.delegate = self

        let content = NSView()
        w.contentView = content

        let bigIcon = NSImageView()
        if let icon = NSApp.applicationIconImage {
            bigIcon.image = icon
        } else if let sysIcon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil) {
            bigIcon.image = sysIcon
        }
        bigIcon.imageScaling = .scaleProportionallyUpOrDown
        bigIcon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Multipaste is installed")
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let subtitle = NSTextField(labelWithString:
            "Press \u{2318}\u{21E7}V anywhere to bring up your clipboard history.")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor

        let feature1 = bullet(symbol: "doc.on.clipboard",
                              title: "Your clipboard, kept around.",
                              detail: "Text, rich text, images, and files — the last 200 of each.")
        let feature2 = bullet(symbol: "keyboard",
                              title: "Snippets that expand anywhere.",
                              detail: "Pin an item, give it a trigger like \u{201C};addr\u{201D}, type the trigger + space to expand it.")
        let feature3 = bullet(symbol: "lock.shield",
                              title: "Private by default.",
                              detail: "Password managers and apps that opt out via NSPasteboard are excluded.")

        // Permission section
        let accLabel = NSTextField(labelWithString: "Accessibility access")
        accLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        accessibilitySummary = NSTextField(wrappingLabelWithString: "")
        accessibilitySummary.font = .systemFont(ofSize: 12)
        accessibilitySummary.textColor = .secondaryLabelColor
        let accBtn = NSButton(title: "Open System Settings", target: self, action: #selector(openAccessibility))
        accBtn.bezelStyle = .rounded

        // Login item section
        let liLabel = NSTextField(labelWithString: "Start at login")
        liLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        loginItemSummary = NSTextField(wrappingLabelWithString: "")
        loginItemSummary.font = .systemFont(ofSize: 12)
        loginItemSummary.textColor = .secondaryLabelColor
        let liEnable = NSButton(title: "Enable", target: self, action: #selector(enableLoginItem))
        liEnable.bezelStyle = .rounded

        let doneBtn = NSButton(title: "Get Started", target: self, action: #selector(close))
        doneBtn.bezelStyle = .rounded
        doneBtn.keyEquivalent = "\r"
        doneBtn.controlSize = .large

        // Layout
        let headerRow = NSStackView(views: [bigIcon, headerStack(title: title, subtitle: subtitle)])
        headerRow.orientation = .horizontal
        headerRow.alignment = .top
        headerRow.spacing = 16

        let featuresStack = NSStackView(views: [feature1, feature2, feature3])
        featuresStack.orientation = .vertical
        featuresStack.alignment = .leading
        featuresStack.spacing = 12

        let accStack = NSStackView(views: [accLabel, accessibilitySummary, accBtn])
        accStack.orientation = .vertical
        accStack.alignment = .leading
        accStack.spacing = 4

        let liStack = NSStackView(views: [liLabel, loginItemSummary, liEnable])
        liStack.orientation = .vertical
        liStack.alignment = .leading
        liStack.spacing = 4

        let permsRow = NSStackView(views: [accStack, divider(), liStack])
        permsRow.orientation = .horizontal
        permsRow.alignment = .top
        permsRow.spacing = 16

        let main = NSStackView(views: [
            headerRow,
            divider(),
            featuresStack,
            divider(),
            permsRow,
            divider(),
            doneBtn,
        ])
        main.orientation = .vertical
        main.alignment = .leading
        main.spacing = 18
        main.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        main.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(main)
        NSLayoutConstraint.activate([
            main.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            main.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            main.topAnchor.constraint(equalTo: content.topAnchor),
            main.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            bigIcon.widthAnchor.constraint(equalToConstant: 64),
            bigIcon.heightAnchor.constraint(equalToConstant: 64),

            featuresStack.widthAnchor.constraint(equalTo: main.widthAnchor, constant: -56),
            accStack.widthAnchor.constraint(equalToConstant: 230),
            liStack.widthAnchor.constraint(equalToConstant: 230),
        ])

        self.window = w
    }

    private func headerStack(title: NSTextField, subtitle: NSTextField) -> NSView {
        let s = NSStackView(views: [title, subtitle])
        s.orientation = .vertical
        s.alignment = .leading
        s.spacing = 4
        return s
    }

    private func bullet(symbol: String, title: String, detail: String) -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        icon.contentTintColor = .controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let t = NSTextField(labelWithString: title)
        t.font = .systemFont(ofSize: 13, weight: .semibold)

        let d = NSTextField(wrappingLabelWithString: detail)
        d.font = .systemFont(ofSize: 12)
        d.textColor = .secondaryLabelColor

        let texts = NSStackView(views: [t, d])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 2

        let row = NSStackView(views: [icon, texts])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 10
        return row
    }

    private func divider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    private func refreshSummaries() {
        accessibilitySummary.stringValue = Permissions.isTrustedForAccessibility
            ? "Granted — picks auto-paste into the focused app."
            : "Not granted yet. Without it, picks land on your clipboard and you press \u{2318}V manually."
        loginItemSummary.stringValue = LoginItem.isEnabled
            ? "Multipaste will start automatically every time you log in."
            : "Not enabled. Click Enable below."
    }

    // MARK: - Actions

    @objc private func openAccessibility() {
        Permissions.walkUserThroughAccessibilityGrant()
        // Refresh summary after a beat so user sees state update on return.
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
            self?.refreshSummaries()
        }
    }

    @objc private func enableLoginItem() {
        if let err = LoginItem.enable() {
            let alert = NSAlert()
            alert.messageText = "Couldn't enable Start at login"
            alert.informativeText = """
                \(err)

                Multipaste needs to live in /Applications or ~/Applications before it can register as a Login Item. Move Multipaste.app there and try again.
                """
            alert.runModal()
            return
        }
        prefs.launchAtLogin = true
        refreshSummaries()
    }

    @objc private func close() {
        prefs.hasCompletedFirstRun = true
        window.orderOut(nil)
        onDone()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        prefs.hasCompletedFirstRun = true
        onDone()
        return true
    }
}
