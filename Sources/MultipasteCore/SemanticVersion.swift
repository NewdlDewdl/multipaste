// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Minimal MAJOR.MINOR.PATCH semver. Pre-release suffixes (`-beta.1`) and
/// build metadata (`+sha`) are not modeled — releases of Multipaste don't
/// use them. Parser accepts an optional leading "v" so GitHub tags
/// (`v1.2.3`) and bundle strings (`1.2.3`) compare equal.
public struct SemanticVersion: Comparable, Equatable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ raw: String) {
        var s = raw
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let M = Int(parts[0]), let m = Int(parts[1]), let p = Int(parts[2]),
              M >= 0, m >= 0, p >= 0
        else { return nil }
        self.major = M
        self.minor = m
        self.patch = p
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (a: SemanticVersion, b: SemanticVersion) -> Bool {
        if a.major != b.major { return a.major < b.major }
        if a.minor != b.minor { return a.minor < b.minor }
        return a.patch < b.patch
    }
}
