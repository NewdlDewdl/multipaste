// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// How a multi-item pick gets delivered to the target app.
public enum MultiPastePlan: Equatable {
    /// Exactly one item picked: identical to the classic single-pick
    /// path. Kept distinct from `.combined` so diagnostics can tell
    /// "user pasted one thing" from "user pasted many things merged".
    case single(ClipboardItem)

    /// All picked items merged into ONE pasteboard write + ONE ⌘V.
    /// Text-like items join with the user's separator; all-file picks
    /// merge into a single multi-file pasteboard (Finder pastes every
    /// file in one go, exactly like a multi-select ⌘C would have).
    case combined(ClipboardItem)

    /// Items that cannot merge (images in the mix) paste one after
    /// another: put → ⌘V → settle → next. Order is mark order.
    case sequential([ClipboardItem])
}

/// Pure policy for turning N picked items into a paste plan.
///
/// Decision table (in priority order):
///
/// | Picked items                       | Plan                            |
/// | ---------------------------------- | ------------------------------- |
/// | none                               | `nil` (nothing to do)           |
/// | exactly one                        | `.single`, classic path        |
/// | all file-URL items                 | `.combined` multi-file pasteboard (order-preserving, deduped) |
/// | all text-representable (text/RTF/files) | `.combined` text joined with the separator |
/// | anything else (an image in the mix)| `.sequential` in mark order     |
///
/// Why combine instead of always pasting sequentially? One pasteboard
/// write + one synthesized ⌘V is atomic from the target app's point of
/// view: no inter-paste timing to race against, works even in apps that
/// debounce rapid keystrokes, and the merged content lands in history as
/// one reusable item. Sequential delivery exists only because there is
/// no meaningful way to concatenate an image with anything.
///
/// Kept AppKit-free (mirrors `PasteRouting` / `TabNavigation`) so every
/// rule above is unit-tested.
public enum MultiPasteComposer {

    /// Pause between sequential pastes, AFTER each synthesized ⌘V and
    /// BEFORE the next pasteboard swap. The target app reads the
    /// pasteboard when it processes the ⌘V from its event queue; swap
    /// too early and item N+1's content lands in item N's paste. 150 ms
    /// is comfortably past observed event-delivery latency while keeping
    /// a 5-item paste under a second.
    public static let sequentialInterItemDelay: TimeInterval = 0.15

    /// The plain-text stand-in for an item, or `nil` if it has none
    /// (images). File-URL items render as their full paths, one per
    /// line, the same representation `PasteboardAugmenter` already
    /// injects for single file copies, so a file mixed into a text
    /// multi-paste behaves consistently with pasting it alone into a
    /// text editor.
    ///
    /// Forwards to `PlainText.string(for:)` so the "plain text of an item"
    /// rule has exactly one definition, shared with the plain-text-paste
    /// feature (⇧↩). A `PlainTextTests` case asserts the two never diverge.
    public static func textRepresentation(of item: ClipboardItem) -> String? {
        PlainText.string(for: item)
    }

    /// Decide how to paste `items` (in the given order). `separator`
    /// joins text-like items in a combined paste; the user picks it in
    /// Preferences (`Preferences.multiPasteSeparator`, default newline).
    public static func plan(items: [ClipboardItem], separator: String) -> MultiPastePlan? {
        guard let first = items.first else { return nil }
        guard items.count > 1 else { return .single(first) }

        if items.allSatisfy(isFileURLs) {
            return .combined(.fileURLs(mergedURLs(of: items)))
        }

        let texts = items.map(textRepresentation(of:))
        if texts.allSatisfy({ $0 != nil }) {
            return .combined(.text(texts.compactMap { $0 }.joined(separator: separator)))
        }

        return .sequential(items)
    }

    // MARK: - Helpers

    private static func isFileURLs(_ item: ClipboardItem) -> Bool {
        if case .fileURLs = item.kind { return true }
        return false
    }

    /// All URLs across the items, mark order preserved, duplicates
    /// dropped (keeping the first occurrence). Pasting the same file
    /// twice in one Finder paste is meaningless, and duplicate URLs in
    /// a single `writeObjects` call would be at the receiver's mercy.
    private static func mergedURLs(of items: [ClipboardItem]) -> [URL] {
        var seen = Set<URL>()
        var merged: [URL] = []
        for item in items {
            guard case .fileURLs(let urls) = item.kind else { continue }
            for url in urls where seen.insert(url).inserted {
                merged.append(url)
            }
        }
        return merged
    }
}
