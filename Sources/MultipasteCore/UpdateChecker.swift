// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

/// Pure update-comparison + GitHub-release JSON parsing logic.
///
/// Network I/O lives in the app target (`UpdateService`); keeping the
/// decision-making here makes it trivially testable: given inputs, what's
/// the status? No mocks, no timeouts.
public enum UpdateChecker {

    public enum Status: Equatable {
        case upToDate
        case updateAvailable(version: SemanticVersion, url: URL, notes: String)
    }

    public struct ParsedRelease: Equatable {
        public let version: SemanticVersion
        public let url: URL
        public let notes: String
    }

    public enum ParseError: Error, Equatable {
        case missingTag
        case missingURL
        case unparseableTag(String)
        case prerelease
        case draft
        case invalidJSON
    }

    /// Decide whether to surface an update. Returns `.upToDate` if the
    /// current version is greater than or equal to latest, or if the user
    /// has chosen to skip exactly `latest` via `skippedVersion`.
    public static func compare(current: SemanticVersion,
                               latest: SemanticVersion,
                               latestURL: URL,
                               notes: String,
                               skippedVersion: SemanticVersion?) -> Status {
        if let skipped = skippedVersion, skipped == latest {
            return .upToDate
        }
        return latest > current
            ? .updateAvailable(version: latest, url: latestURL, notes: notes)
            : .upToDate
    }

    /// Parse a GitHub `/repos/:owner/:repo/releases/latest` payload.
    /// Rejects drafts and prereleases — these shouldn't be foisted on
    /// users via auto-update.
    public static func parseGitHubRelease(_ data: Data) throws -> ParsedRelease {
        guard let any = try? JSONSerialization.jsonObject(with: data),
              let dict = any as? [String: Any]
        else { throw ParseError.invalidJSON }

        if (dict["draft"] as? Bool) == true { throw ParseError.draft }
        if (dict["prerelease"] as? Bool) == true { throw ParseError.prerelease }

        guard let tag = dict["tag_name"] as? String else { throw ParseError.missingTag }
        guard let version = SemanticVersion(tag) else { throw ParseError.unparseableTag(tag) }

        guard let urlStr = dict["html_url"] as? String,
              let url = URL(string: urlStr)
        else { throw ParseError.missingURL }

        let notes = (dict["body"] as? String) ?? ""
        return ParsedRelease(version: version, url: url, notes: notes)
    }
}
