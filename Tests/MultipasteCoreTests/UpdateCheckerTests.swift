import Foundation
@testable import MultipasteCore

enum UpdateCheckerTests {

    static func registerAll() {
        TestRegistry.register("UpdateChecker/sameVersionIsUpToDate", sameVersionIsUpToDate)
        TestRegistry.register("UpdateChecker/newerLatestSignalsUpdate", newerLatestSignalsUpdate)
        TestRegistry.register("UpdateChecker/olderLatestIsUpToDate", olderLatestIsUpToDate)
        TestRegistry.register("UpdateChecker/skipsSkippedVersion", skipsSkippedVersion)
        TestRegistry.register("UpdateChecker/parseReleaseJSON", parseReleaseJSON)
        TestRegistry.register("UpdateChecker/parseReleaseJSONMissingFields", parseReleaseJSONMissingFields)
    }

    private static let releaseURL = URL(string: "https://github.com/NewdlDewdl/multipaste/releases/tag/v9.9.9")!

    static func sameVersionIsUpToDate() throws {
        let cur = SemanticVersion("1.2.0")!
        let result = UpdateChecker.compare(current: cur,
                                           latest: cur,
                                           latestURL: releaseURL,
                                           notes: "",
                                           skippedVersion: nil)
        try expectEqual(result, .upToDate)
    }

    static func newerLatestSignalsUpdate() throws {
        let cur = SemanticVersion("1.2.0")!
        let latest = SemanticVersion("1.3.0")!
        let result = UpdateChecker.compare(current: cur,
                                           latest: latest,
                                           latestURL: releaseURL,
                                           notes: "new stuff",
                                           skippedVersion: nil)
        switch result {
        case .updateAvailable(let version, let url, let notes):
            try expectEqual(version, latest)
            try expectEqual(url, releaseURL)
            try expectEqual(notes, "new stuff")
        default:
            throw TestFailure(message: "expected .updateAvailable, got \(result)",
                              file: #file, line: #line)
        }
    }

    static func olderLatestIsUpToDate() throws {
        // Local build ahead of public release? Don't pester the user with
        // a "downgrade available" prompt — treat as up-to-date.
        let cur = SemanticVersion("2.0.0")!
        let latest = SemanticVersion("1.9.9")!
        let result = UpdateChecker.compare(current: cur,
                                           latest: latest,
                                           latestURL: releaseURL,
                                           notes: "",
                                           skippedVersion: nil)
        try expectEqual(result, .upToDate)
    }

    static func skipsSkippedVersion() throws {
        let cur = SemanticVersion("1.2.0")!
        let latest = SemanticVersion("1.3.0")!
        let result = UpdateChecker.compare(current: cur,
                                           latest: latest,
                                           latestURL: releaseURL,
                                           notes: "",
                                           skippedVersion: latest)
        try expectEqual(result, .upToDate, "user clicked Skip on this version — don't re-prompt")
    }

    static func parseReleaseJSON() throws {
        let json = """
        {
          "tag_name": "v1.3.0",
          "html_url": "https://github.com/NewdlDewdl/multipaste/releases/tag/v1.3.0",
          "body": "## What's new\\n- thing one",
          "draft": false,
          "prerelease": false
        }
        """.data(using: .utf8)!
        let parsed = try UpdateChecker.parseGitHubRelease(json)
        try expectEqual(parsed.version, SemanticVersion("1.3.0"))
        try expectEqual(parsed.url.absoluteString, "https://github.com/NewdlDewdl/multipaste/releases/tag/v1.3.0")
        try expect(parsed.notes.contains("thing one"))
    }

    static func parseReleaseJSONMissingFields() throws {
        let json = "{}".data(using: .utf8)!
        var didThrow = false
        do {
            _ = try UpdateChecker.parseGitHubRelease(json)
        } catch {
            didThrow = true
        }
        try expect(didThrow, "missing required fields should throw")
    }
}
