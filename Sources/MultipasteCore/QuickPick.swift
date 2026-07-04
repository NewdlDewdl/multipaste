// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Policy for the ⌘1-9 quick-pick digits: which rows get a digit label
/// and which item each digit pastes. ONE source of truth consumed by all
/// three surfaces (picker badge, picker ⌘digit handler, menu bar
/// key equivalents) so they cannot drift apart.
///
/// Digits target the RECENT rail: the first nine UNPINNED items in
/// display order. Pinned rows carry no digit. Rationale: pinned items
/// are the stable rail (they never move, so a digit adds no speed over
/// muscle memory and the mouse), while recents are exactly what ⌘1-9 is
/// for; when digits counted pinned rows first, pinning four items meant
/// ⌘1-⌘4 could never hit the thing you just copied (Rohin, 2026-07-04).
/// Display ORDER is unchanged (pinned still sort first, v2.1.1); only
/// the digit targeting skips them.
public enum QuickPick {

    /// ⌘1 through ⌘9.
    public static let maxDigits = 9

    /// Per-row digit labels for a display-ordered item list: the value
    /// at index `i` is the 1-based digit shown on row `i`, or nil for a
    /// pinned row or a row past the ⌘9 budget.
    public static func labels(for items: [ClipboardItem]) -> [Int?] {
        var next = 1
        return items.map { item in
            guard !item.pinned, next <= maxDigits else { return nil }
            defer { next += 1 }
            return next
        }
    }

    /// The item ⌘`digit` pastes, given the SAME display-ordered list the
    /// labels were computed from. nil when the digit is out of the 1-9
    /// range or fewer unpinned rows exist.
    public static func target(digit: Int, in items: [ClipboardItem]) -> ClipboardItem? {
        guard (1...maxDigits).contains(digit) else { return nil }
        var seen = 0
        for item in items where !item.pinned {
            seen += 1
            if seen == digit { return item }
        }
        return nil
    }
}
