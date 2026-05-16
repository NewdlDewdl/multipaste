// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Pure trigger-matching logic. Given a typed buffer (the user's recent
/// keystrokes) and the set of known snippets, returns the snippet (if any)
/// that should fire right now and how many trailing characters to delete
/// from the user's text (the trigger + the terminator).
///
/// Kept platform-free so it can be unit-tested without an event tap.
public enum SnippetMatcher {

    public struct Match: Equatable {
        public let snippet: ClipboardItem
        /// Trigger length + 1 for the terminator.
        public let charsToDelete: Int
    }

    /// Characters that "commit" a trigger.
    public static let terminators: Set<Character> = [" ", "\t", "\n", "\r"]

    public static func match(buffer: String, snippets: [ClipboardItem]) -> Match? {
        guard let last = buffer.last, terminators.contains(last) else { return nil }
        let body = String(buffer.dropLast())

        // Prefer the longest matching trigger to avoid eager short matches
        // (e.g. ";m" stealing ";email").
        var best: Match?
        for s in snippets {
            guard s.pinned,
                  let t = s.trigger,
                  !t.isEmpty,
                  body.hasSuffix(t)
            else { continue }
            if (best?.snippet.trigger?.count ?? 0) < t.count {
                best = Match(snippet: s, charsToDelete: t.count + 1)
            }
        }
        return best
    }
}
