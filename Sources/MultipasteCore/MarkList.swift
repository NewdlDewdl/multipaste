// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Ordered set of "marked" elements for the picker's multi-paste mode.
///
/// The picker lets the user mark several history items (⌥↩, ⌘-click,
/// Space) and then paste them ALL with a single ↩. Two properties matter
/// and both live here, AppKit-free, so they're unit-testable:
///
/// 1. **Order is mark order, not display order.** If you mark row 5,
///    then row 1, then row 3, the paste comes out 5-1-3. The badge each
///    row shows is its 1-based position in this list, so what you see
///    is exactly the order you'll get.
/// 2. **Marks survive re-filtering.** Marks key on element identity
///    (the item's UUID), not row index, so you can mark something,
///    type a new search, mark something else, and paste both. They are
///    pruned only when the underlying item stops existing (deleted or
///    evicted), via `prune(keeping:)`.
///
/// Mirrors `TabNavigation` / `PasteRouting`: pure policy here, the
/// `PickerWindow` just renders it.
public struct MarkList<Element: Hashable>: Equatable {

    /// Marked elements in the order they were marked. Index 0 pastes first.
    public private(set) var ids: [Element] = []

    /// O(1) membership mirror of `ids`.
    private var membership: Set<Element> = []

    public init() {}

    public var isEmpty: Bool { ids.isEmpty }
    public var count: Int { ids.count }

    public func contains(_ element: Element) -> Bool {
        membership.contains(element)
    }

    /// 1-based position of `element` in paste order: what the row badge
    /// displays. `nil` when unmarked.
    public func position(of element: Element) -> Int? {
        guard membership.contains(element) else { return nil }
        return ids.firstIndex(of: element).map { $0 + 1 }
    }

    /// Mark if unmarked (appending to the end of the paste order),
    /// unmark if marked (later marks renumber down to fill the gap).
    public mutating func toggle(_ element: Element) {
        if membership.contains(element) {
            membership.remove(element)
            ids.removeAll { $0 == element }
        } else {
            membership.insert(element)
            ids.append(element)
        }
    }

    public mutating func clear() {
        ids.removeAll()
        membership.removeAll()
    }

    /// Mark-all / unmark-all over the currently *visible* elements
    /// (⌥⌘A in the picker).
    ///
    /// - If every visible element is already marked → unmark all of
    ///   them (marks on non-visible elements survive), so pressing
    ///   ⌥⌘A twice is a no-op.
    /// - Otherwise → mark the missing ones, appended in the given
    ///   (display) order. Existing marks keep their positions; the
    ///   user's hand-picked order is never silently reshuffled.
    public mutating func toggleAll(_ visible: [Element]) {
        guard !visible.isEmpty else { return }
        if visible.allSatisfy(membership.contains) {
            let drop = Set(visible)
            membership.subtract(drop)
            ids.removeAll { drop.contains($0) }
        } else {
            for element in visible where !membership.contains(element) {
                membership.insert(element)
                ids.append(element)
            }
        }
    }

    /// Drop marks whose element no longer exists (item deleted from
    /// history, evicted past the cap…). Survivors keep their relative
    /// order. Call whenever the underlying store reloads.
    public mutating func prune(keeping valid: Set<Element>) {
        guard !membership.isSubset(of: valid) else { return }
        membership.formIntersection(valid)
        ids.removeAll { !valid.contains($0) }
    }
}
