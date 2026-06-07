// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// How to deliver a synthesized ⌘V back to the app the user actually
/// wants to paste into.
public enum PasteRoute: Equatable {
    /// The previous app still has focus (the non-activating picker never
    /// stole it). Just settle one runloop hop and paste — no activation,
    /// no polling, no race.
    case immediate

    /// Focus is currently on Multipaste itself (the picker ended up
    /// activating us, or this is an edge case). Hand focus back to the
    /// previous app cooperatively, wait for it to actually return, then
    /// paste. This is the fallback path; it should be rare.
    case restoreFocus

    /// We're frontmost and there is no known previous app to paste into.
    /// Synthesizing ⌘V here would paste into Multipaste itself, so we
    /// don't: the item is already on the clipboard and the user can ⌘V
    /// it wherever they like.
    case clipboardOnly
}

/// Pure decision policy for the picker's paste path.
///
/// Background: through v2.1.3 the picker activated Multipaste to receive
/// keystrokes, then — on paste — re-activated the previous app and polled
/// `NSWorkspace.frontmostApplication` until it matched before synthesizing
/// ⌘V. The poll *always* reported success, yet pastes still dropped:
/// `frontmostApplication == target` is necessary but not sufficient,
/// because a freshly re-activated Chromium/Electron app reports frontmost
/// a beat before its content view can accept a synthesized keystroke.
///
/// v2.2.0 makes the picker a true non-activating panel, so the previous
/// app keeps focus the whole time and the common case becomes `.immediate`
/// — no activation round-trip to race against. `.restoreFocus` survives
/// only as a safety net for the rare case where focus did land on us.
///
/// Kept here, AppKit-free, so the routing rule is unit-testable without a
/// running app (mirrors `TabNavigation`).
public enum PasteRouting {

    /// Decide how to paste.
    ///
    /// - Parameters:
    ///   - weAreFrontmost: is Multipaste itself the frontmost application
    ///     right now?
    ///   - hasPreviousApp: did we capture the app that was frontmost before
    ///     the picker opened?
    public static func route(weAreFrontmost: Bool, hasPreviousApp: Bool) -> PasteRoute {
        guard weAreFrontmost else {
            // Someone other than us is frontmost — overwhelmingly the
            // previous app, which kept focus because the panel is
            // non-activating. Paste straight into it.
            return .immediate
        }
        // We're frontmost. Paste only if we know where to send it.
        return hasPreviousApp ? .restoreFocus : .clipboardOnly
    }
}
