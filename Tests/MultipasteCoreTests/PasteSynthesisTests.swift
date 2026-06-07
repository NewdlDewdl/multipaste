// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

/// Locks down the ⌘V flag composition. The whole point of this suite is to
/// fail loudly if anyone "simplifies" `commandVFlags` back to a bare
/// `maskCommand` — that regression is invisible on native apps but silently
/// breaks pasting into every Chromium/Electron app (Claude desktop, Codex,
/// Slack, VS Code). See `PasteSynthesis` for the Flycut-#18 rationale.
enum PasteSynthesisTests {

    static func registerAll() {
        TestRegistry.register("PasteSynthesis/vKeyCodeIsV", vKeyCodeIsV)
        TestRegistry.register("PasteSynthesis/commandMaskMatchesNXCommandMask", commandMaskMatchesNXCommandMask)
        TestRegistry.register("PasteSynthesis/leftCommandDeviceBitIsNXDeviceLCmd", leftCommandDeviceBitIsNXDeviceLCmd)
        TestRegistry.register("PasteSynthesis/commandVFlagsIncludesGenericCommand", commandVFlagsIncludesGenericCommand)
        TestRegistry.register("PasteSynthesis/commandVFlagsIncludesLeftCommandDeviceBit", commandVFlagsIncludesLeftCommandDeviceBit)
        TestRegistry.register("PasteSynthesis/commandVFlagsExactValue", commandVFlagsExactValue)
        TestRegistry.register("PasteSynthesis/commandVFlagsIsNotBareCommandMask", commandVFlagsIsNotBareCommandMask)
    }

    static func vKeyCodeIsV() throws {
        // kVK_ANSI_V == 0x09. If this drifts, we'd be synthesizing the
        // wrong key entirely.
        try expectEqual(PasteSynthesis.vKeyCode, 9)
    }

    static func commandMaskMatchesNXCommandMask() throws {
        // NX_COMMANDMASK / CGEventFlags.maskCommand == 1 << 20.
        try expectEqual(PasteSynthesis.commandMask, 0x10_0000)
        try expectEqual(PasteSynthesis.commandMask, UInt64(1) << 20)
    }

    static func leftCommandDeviceBitIsNXDeviceLCmd() throws {
        // NX_DEVICELCMDKEYMASK == 0x8 (verified in IOLLEvent.h).
        try expectEqual(PasteSynthesis.leftCommandDeviceBit, 0x8)
    }

    static func commandVFlagsIncludesGenericCommand() throws {
        try expect(PasteSynthesis.commandVFlags & PasteSynthesis.commandMask != 0,
                   "⌘V flags must carry the generic Command mask")
    }

    static func commandVFlagsIncludesLeftCommandDeviceBit() throws {
        // THE regression guard: this device bit is what makes Chromium /
        // Electron honor the synthesized Command. Without it the paste
        // silently degrades to a bare "v".
        try expect(PasteSynthesis.commandVFlags & PasteSynthesis.leftCommandDeviceBit != 0,
                   "⌘V flags must carry the left-Command device bit (Flycut #18) or Electron drops the paste")
    }

    static func commandVFlagsExactValue() throws {
        // 0x10_0000 | 0x8 == 0x10_0008.
        try expectEqual(PasteSynthesis.commandVFlags, 0x10_0008)
    }

    static func commandVFlagsIsNotBareCommandMask() throws {
        // The exact mistake we're guarding against: flags == maskCommand
        // with no device bit. That's the v2.1.3 bug.
        try expectNotEqual(PasteSynthesis.commandVFlags, PasteSynthesis.commandMask)
    }
}
