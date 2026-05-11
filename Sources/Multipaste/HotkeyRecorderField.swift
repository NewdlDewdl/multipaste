import AppKit
import Carbon.HIToolbox
import MultipasteCore

/// Click-to-record hotkey input. Click → "Press shortcut…" → next valid
/// combo is captured and reported via `onCapture`. Invalid combos (no
/// modifier, or modifier-only) are rejected with a brief visual flash.
final class HotkeyRecorderField: NSControl {

    var hotkey: Hotkey {
        didSet { needsDisplay = true }
    }

    /// Called with the captured value when the user records a new combo.
    var onCapture: ((Hotkey) -> Void)?

    private var isRecording = false {
        didSet { needsDisplay = true }
    }
    private var localMonitor: Any?
    private var label: NSTextField!

    init(initial: Hotkey) {
        self.hotkey = initial
        super.init(frame: .zero)
        setupLabel()
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.6).cgColor
        layer?.borderWidth = 1
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupLabel() {
        label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
        ])
        refreshLabel()
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 30) }

    override func mouseDown(with event: NSEvent) {
        startRecording()
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        refreshLabel()
        layer?.borderColor = NSColor.controlAccentColor.cgColor

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] ev in
            guard let self = self, self.isRecording else { return ev }
            if ev.type == .keyDown {
                if ev.keyCode == 53 { // Esc — cancel
                    self.endRecording()
                    return nil
                }
                let mods = HotkeyRecorderField.modifiers(from: ev.modifierFlags)
                // Require at least one modifier to avoid swallowing plain keys.
                guard !mods.isEmpty else {
                    self.flashInvalid()
                    return nil
                }
                let captured = Hotkey(keyCode: Int(ev.keyCode), modifiers: mods)
                self.hotkey = captured
                self.onCapture?(captured)
                self.endRecording()
                return nil
            }
            return ev
        }
    }

    private func endRecording() {
        isRecording = false
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        localMonitor = nil
        refreshLabel()
        layer?.borderColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.6).cgColor
    }

    private func flashInvalid() {
        layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.15).cgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(180)) { [weak self] in
            self?.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        }
    }

    private func refreshLabel() {
        if isRecording {
            label.stringValue = "Press shortcut… (esc to cancel)"
            label.textColor = .controlAccentColor
        } else {
            label.stringValue = HotkeyRecorderField.display(hotkey)
            label.textColor = .labelColor
        }
    }

    // MARK: - Conversion helpers

    static func modifiers(from flags: NSEvent.ModifierFlags) -> HotkeyModifiers {
        var m: HotkeyModifiers = []
        if flags.contains(.command) { m.insert(.command) }
        if flags.contains(.shift)   { m.insert(.shift) }
        if flags.contains(.option)  { m.insert(.option) }
        if flags.contains(.control) { m.insert(.control) }
        return m
    }

    /// "⌃⌥⇧⌘V" style. Modifier order matches macOS HIG.
    static func display(_ h: Hotkey) -> String {
        var s = ""
        if h.modifiers.contains(.control) { s += "⌃" }
        if h.modifiers.contains(.option)  { s += "⌥" }
        if h.modifiers.contains(.shift)   { s += "⇧" }
        if h.modifiers.contains(.command) { s += "⌘" }
        s += keyDisplay(h.keyCode)
        return s
    }

    /// Maps macOS virtual key codes to glyphs. Covers the common cases;
    /// falls back to "key-N" so an unknown code never looks like a typo.
    static func keyDisplay(_ keyCode: Int) -> String {
        switch keyCode {
        case 0: return "A"; case 1: return "S"; case 2: return "D"
        case 3: return "F"; case 4: return "H"; case 5: return "G"
        case 6: return "Z"; case 7: return "X"; case 8: return "C"
        case 9: return "V"; case 11: return "B"; case 12: return "Q"
        case 13: return "W"; case 14: return "E"; case 15: return "R"
        case 16: return "Y"; case 17: return "T"; case 31: return "O"
        case 32: return "U"; case 34: return "I"; case 35: return "P"
        case 37: return "L"; case 38: return "J"; case 40: return "K"
        case 45: return "N"; case 46: return "M"
        case 18: return "1"; case 19: return "2"; case 20: return "3"
        case 21: return "4"; case 22: return "6"; case 23: return "5"
        case 25: return "9"; case 26: return "7"; case 28: return "8"; case 29: return "0"
        case 36: return "↩"; case 48: return "⇥"; case 49: return "Space"
        case 51: return "⌫"; case 53: return "⎋"; case 117: return "⌦"
        case 122: return "F1"; case 120: return "F2"; case 99: return "F3"
        case 118: return "F4"; case 96: return "F5"; case 97: return "F6"
        case 98: return "F7"; case 100: return "F8"; case 101: return "F9"
        case 109: return "F10"; case 103: return "F11"; case 111: return "F12"
        case 123: return "←"; case 124: return "→"; case 125: return "↓"; case 126: return "↑"
        default: return "key-\(keyCode)"
        }
    }
}
