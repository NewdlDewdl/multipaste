import AppKit
import Carbon.HIToolbox
import MultipasteCore

/// Registers a single global hotkey via Carbon's `RegisterEventHotKey`.
///
/// Carbon hotkeys do NOT require Accessibility permission — they're routed
/// through the system event manager. (Synthesizing key events for paste
/// _does_ require Accessibility; that's a separate prompt in `Paster`.)
final class HotKeyManager {

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = OSType(0x4D505354) // 'MPST'
    private var handler: (() -> Void)?

    func register(_ hotkey: Hotkey, handler: @escaping () -> Void) {
        unregister()
        self.handler = handler

        let id = EventHotKeyID(signature: signature, id: 1)
        var carbonMods: UInt32 = 0
        if hotkey.modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if hotkey.modifiers.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
        if hotkey.modifiers.contains(.option)  { carbonMods |= UInt32(optionKey) }
        if hotkey.modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let ud = userData else { return noErr }
                let mgr = Unmanaged<HotKeyManager>.fromOpaque(ud).takeUnretainedValue()
                mgr.handler?()
                return noErr
            },
            1, &spec, selfPtr, &handlerRef
        )

        RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            carbonMods,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let r = hotKeyRef {
            UnregisterEventHotKey(r)
            hotKeyRef = nil
        }
        if let h = handlerRef {
            RemoveEventHandler(h)
            handlerRef = nil
        }
        handler = nil
    }

    deinit { unregister() }
}
