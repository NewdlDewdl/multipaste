// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation
@testable import MultipasteCore

// The Settings popup ↔ stored-literal mapping for the multi-paste
// separator. The preference stores the LITERAL (self-describing,
// hand-editable via `defaults write`), so the round-trip through
// `from(literal:)` is what keeps the popup honest.

enum MultiPasteSeparatorTests {

    static func registerAll() {
        TestRegistry.register("MultiPasteSeparator/literalsAreExactlyTheAdvertisedStrings", literalsAreExactlyTheAdvertisedStrings)
        TestRegistry.register("MultiPasteSeparator/everyChoiceRoundTripsThroughItsLiteral", everyChoiceRoundTripsThroughItsLiteral)
        TestRegistry.register("MultiPasteSeparator/literalsAreUniqueSoReverseLookupIsUnambiguous", literalsAreUniqueSoReverseLookupIsUnambiguous)
        TestRegistry.register("MultiPasteSeparator/unknownLiteralHasNoChoice", unknownLiteralHasNoChoice)
        TestRegistry.register("MultiPasteSeparator/labelsAreNonEmptyAndUnique", labelsAreNonEmptyAndUnique)
        TestRegistry.register("MultiPasteSeparator/defaultPreferenceIsNewline", defaultPreferenceIsNewline)
    }

    static func literalsAreExactlyTheAdvertisedStrings() throws {
        try expectEqual(MultiPasteSeparatorChoice.newline.literal, "\n")
        try expectEqual(MultiPasteSeparatorChoice.blankLine.literal, "\n\n")
        try expectEqual(MultiPasteSeparatorChoice.space.literal, " ")
        try expectEqual(MultiPasteSeparatorChoice.tab.literal, "\t")
        try expectEqual(MultiPasteSeparatorChoice.nothing.literal, "")
    }

    static func everyChoiceRoundTripsThroughItsLiteral() throws {
        for choice in MultiPasteSeparatorChoice.allCases {
            try expectEqual(MultiPasteSeparatorChoice.from(literal: choice.literal), choice,
                            "choice \(choice.rawValue) must survive store-and-reload")
        }
    }

    static func literalsAreUniqueSoReverseLookupIsUnambiguous() throws {
        let literals = MultiPasteSeparatorChoice.allCases.map(\.literal)
        try expectEqual(Set(literals).count, literals.count,
                        "two choices with the same literal would make the popup selection ambiguous")
    }

    static func unknownLiteralHasNoChoice() throws {
        try expectEqual(MultiPasteSeparatorChoice.from(literal: " ~ "), nil,
                        "hand-written separators are honored by the composer but have no popup row")
    }

    static func labelsAreNonEmptyAndUnique() throws {
        let labels = MultiPasteSeparatorChoice.allCases.map(\.label)
        try expect(labels.allSatisfy { !$0.isEmpty })
        try expectEqual(Set(labels).count, labels.count,
                        "duplicate popup titles would be indistinguishable in Settings")
    }

    /// Cross-check: the registered default in Preferences is the newline
    /// choice's literal, so the popup's initial selection matches what
    /// the composer actually uses on a fresh install.
    static func defaultPreferenceIsNewline() throws {
        let suite = "com.rohin.multipaste.tests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        let p = Preferences(defaults: d)
        try expectEqual(p.multiPasteSeparator, MultiPasteSeparatorChoice.newline.literal)
        try expectEqual(MultiPasteSeparatorChoice.from(literal: p.multiPasteSeparator), .newline)
    }
}
