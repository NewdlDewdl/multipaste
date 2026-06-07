// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Pure policy for the modifier flags and virtual key code used to
/// synthesize the paste keystroke (⌘V). Kept AppKit/CoreGraphics-free so
/// the *exact* flag composition is unit-testable without a running app —
/// the app layer (`Paster`) turns these raw values into `CGEventFlags` /
/// `CGKeyCode`.
///
/// ## Why a `0x8` bit you'll be tempted to "clean up"
///
/// The obvious way to synthesize ⌘V is to set only the generic Command
/// mask (`NX_COMMANDMASK` = `0x10_0000`, what AppKit calls
/// `CGEventFlags.maskCommand`). That is exactly what Multipaste did
/// through v2.1.3 — and it is why pasting into Chromium/Electron apps
/// (Claude desktop, Codex, VS Code, Slack…) intermittently dropped the
/// paste: those apps inspect the **device-dependent** left/right Command
/// bit, not just the generic mask. If neither `NX_DEVICELCMDKEYMASK`
/// (`0x8`) nor `NX_DEVICERCMDKEYMASK` (`0x10`) is set, they treat the
/// Command modifier as absent and the keystroke degrades to a bare "v"
/// (or is ignored entirely).
///
/// This is the long-documented Flycut fix (TermiT/Flycut PR #18, also
/// adopted by Maccy's `Clipboard.paste()`); the rationale there is about
/// Emacs, but the same modifier inspection is what bites Chromium. We set
/// the **left**-Command device bit alongside the generic mask, matching
/// Maccy.
///
/// The two constants are verified against the macOS SDK header
/// `IOKit.framework/Headers/hidsystem/IOLLEvent.h`:
///   `#define NX_COMMANDMASK        0x00100000`
///   `#define NX_DEVICELCMDKEYMASK  0x00000008`
public enum PasteSynthesis {

    /// Virtual key code for the "V" key (ANSI `kVK_ANSI_V`). Stable across
    /// keyboard layouts at the virtual-keycode layer.
    public static let vKeyCode: UInt16 = 9

    /// Generic Command modifier mask (`NX_COMMANDMASK`). Equal to
    /// `CGEventFlags.maskCommand.rawValue` (`1 << 20`).
    public static let commandMask: UInt64 = 0x10_0000

    /// Left-Command device-dependent bit (`NX_DEVICELCMDKEYMASK`). The bit
    /// Chromium/Electron require in order to honor a synthesized Command.
    public static let leftCommandDeviceBit: UInt64 = 0x8

    /// The flags to stamp on BOTH the key-down and key-up of a synthesized
    /// ⌘V: generic Command mask OR'd with the left-Command device bit.
    ///
    /// `0x10_0000 | 0x8 == 0x10_0008`.
    public static var commandVFlags: UInt64 {
        commandMask | leftCommandDeviceBit
    }
}
