// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

/// Covers the picker's paste-path routing. The important properties:
///  - if the previous app kept focus (the non-activating panel did its
///    job), we paste immediately — no activation round-trip to race;
///  - we only fall back to re-activating focus when we (Multipaste) are
///    actually the frontmost app;
///  - we never blindly synthesize ⌘V with nowhere safe to send it (which
///    would paste into Multipaste itself).
enum PasteRoutingTests {

    static func registerAll() {
        TestRegistry.register("PasteRouting/previousAppKeptFocusPastesImmediately", previousAppKeptFocusPastesImmediately)
        TestRegistry.register("PasteRouting/immediateEvenWithoutCapturedPrevApp", immediateEvenWithoutCapturedPrevApp)
        TestRegistry.register("PasteRouting/weAreFrontmostWithTargetRestoresFocus", weAreFrontmostWithTargetRestoresFocus)
        TestRegistry.register("PasteRouting/weAreFrontmostNoTargetIsClipboardOnly", weAreFrontmostNoTargetIsClipboardOnly)
    }

    static func previousAppKeptFocusPastesImmediately() throws {
        // The happy path post-fix: panel is non-activating, the prior app
        // never lost focus, so paste straight in.
        try expectEqual(
            PasteRouting.route(weAreFrontmost: false, hasPreviousApp: true),
            .immediate
        )
    }

    static func immediateEvenWithoutCapturedPrevApp() throws {
        // If we're not frontmost, *someone else* is, and that's who the
        // user is looking at — paste into them even if we never captured a
        // reference (e.g. the picker was opened from an already-foreground
        // app we couldn't snapshot).
        try expectEqual(
            PasteRouting.route(weAreFrontmost: false, hasPreviousApp: false),
            .immediate
        )
    }

    static func weAreFrontmostWithTargetRestoresFocus() throws {
        // Fallback: focus ended up on us, but we know where it belongs.
        try expectEqual(
            PasteRouting.route(weAreFrontmost: true, hasPreviousApp: true),
            .restoreFocus
        )
    }

    static func weAreFrontmostNoTargetIsClipboardOnly() throws {
        // We're frontmost and don't know the target — synthesizing ⌘V
        // would paste into Multipaste. Leave it on the clipboard instead.
        try expectEqual(
            PasteRouting.route(weAreFrontmost: true, hasPreviousApp: false),
            .clipboardOnly
        )
    }
}
