// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Pure helpers for the "file copy → path text" feature.
///
/// macOS Finder puts only `public.file-url` (and a few legacy URL types)
/// on the pasteboard when a file is copied — no `public.utf8-plain-text`.
/// That means pasting a file into a code editor or any text-only control
/// gives nothing useful. Multipaste augments such pasteboards with the
/// full file path as the string representation, so:
///
/// - text-only consumers (code editor, terminal, search field) → paste path
/// - file-URL consumers (chat composer, Finder, image editor) → paste file
///
/// Both representations coexist on the same pasteboard; the receiving
/// control picks whichever type it wants.
public enum PasteboardAugmenter {

    /// Joined file paths, newline-separated, ready to use as the
    /// `.string` representation.
    public static func pathText(forFiles urls: [URL]) -> String {
        urls.map(\.path).joined(separator: "\n")
    }

    /// True if `existing` is already a useful string representation —
    /// i.e. not nil, not empty after whitespace trim. When false, we
    /// safely overwrite/inject the path text.
    public static func shouldAugment(existing: String?) -> Bool {
        let trimmed = existing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty
    }
}
