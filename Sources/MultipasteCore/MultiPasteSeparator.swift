// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// The user-selectable separators for combined text multi-pastes,
/// surfaced as a popup in Preferences → General.
///
/// The preference itself (`Preferences.multiPasteSeparator`) stores the
/// raw literal string, NOT this enum's case name, so the storage format
/// is self-describing, survives this enum gaining/losing cases, and a
/// power user could even write an arbitrary separator straight into the
/// defaults plist:
///
///     defaults write com.rohin.multipaste multiPasteSeparator " · "
///
/// The popup maps literal ↔ choice via `from(literal:)`; an unrecognized
/// literal simply shows no popup selection while still being honored by
/// the composer.
public enum MultiPasteSeparatorChoice: String, CaseIterable, Equatable {
    case newline
    case blankLine
    case space
    case tab
    case nothing

    /// The exact string placed between items in a combined text paste.
    public var literal: String {
        switch self {
        case .newline:   return "\n"
        case .blankLine: return "\n\n"
        case .space:     return " "
        case .tab:       return "\t"
        case .nothing:   return ""
        }
    }

    /// Human-readable popup title.
    public var label: String {
        switch self {
        case .newline:   return "New line (one item per line)"
        case .blankLine: return "Blank line (paragraph per item)"
        case .space:     return "Space"
        case .tab:       return "Tab"
        case .nothing:   return "Nothing (run items together)"
        }
    }

    /// Reverse lookup for the Settings popup. `nil` for separators that
    /// don't correspond to a built-in choice (e.g. one hand-written via
    /// `defaults write`).
    public static func from(literal: String) -> MultiPasteSeparatorChoice? {
        allCases.first { $0.literal == literal }
    }
}
