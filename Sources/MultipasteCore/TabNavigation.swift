// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Pure state machine for Tab / Shift+Tab navigation in the picker.
///
/// The picker presents a search field plus a list of N rows. Tab steps
/// forward through the sequence
///
///     search → row(0) → row(1) → … → row(N-1)
///
/// stopping at `row(N-1)` if Tab is pressed at the end. Shift+Tab steps
/// backward
///
///     row(N-1) → … → row(0) → search
///
/// stopping at `search` (we don't wrap around — the user can press Esc
/// to dismiss the panel entirely if they want).
///
/// Keeping the rules here, not in `PickerWindow`, means the policy is
/// trivially testable and can be evolved (wrap-around, skip-disabled-
/// rows, etc.) without touching any AppKit state.
public enum FocusedRegion: Equatable {
    case searchField
    case row(Int)
}

public enum TabNavigation {

    /// Where Tab goes from `current`, given `totalRows` visible rows.
    public static func next(from current: FocusedRegion, totalRows: Int) -> FocusedRegion {
        switch current {
        case .searchField:
            // Empty list — staying in the search field is the least
            // surprising option (a "missing focus" feels broken).
            return totalRows > 0 ? .row(0) : .searchField
        case .row(let i):
            // Clamp at the last row instead of wrapping. Wrap would
            // make Tab feel "lossy" — you'd have to count back to know
            // where you are. Stop at the end is the convention.
            return i + 1 < totalRows ? .row(i + 1) : .row(i)
        }
    }

    /// Where Shift+Tab goes from `current`, given `totalRows`.
    public static func previous(from current: FocusedRegion, totalRows: Int) -> FocusedRegion {
        switch current {
        case .searchField:
            // Shift+Tab from the search field is a no-op. We could wrap
            // to the last row, but the search field is the "anchor"
            // position and users press it to escape selection back to
            // typing — surprising them by jumping to the bottom feels
            // wrong.
            return .searchField
        case .row(0):
            return .searchField
        case .row(let i):
            return .row(i - 1)
        }
    }
}
