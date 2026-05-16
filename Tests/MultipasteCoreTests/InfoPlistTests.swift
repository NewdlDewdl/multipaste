// SPDX-FileCopyrightText: Copyright (c) 2026 Rohin Agrawal
// SPDX-License-Identifier: LicenseRef-PolyForm-Strict-1.0.0

import Foundation

// Verifies Resources/Info.plist has every key macOS needs to launch the
// app correctly. A missing or malformed Info.plist key can produce
// silent rejection at launch (the app crashes immediately with no UI
// indication) — exactly the bug class that a user on a fresh Mac
// would experience as "I downloaded it, double-clicked it, and
// nothing happened."
//
// Specifically locked in here:
//   - CFBundleIdentifier matches MultipasteVersion.bundleIdentifier
//     (so the running app's view of itself agrees with macOS's view).
//   - CFBundlePackageType = APPL (macOS won't treat it as an app
//     bundle otherwise).
//   - NSPrincipalClass = NSApplication (required for AppKit apps).
//   - LSUIElement = true (no Dock icon — Multipaste is a menubar app).
//   - LSMinimumSystemVersion = 13.0 (matches the audit-confirmed
//     floor; raising this means dropping Ventura users, which is a
//     deliberate decision, not a typo).
//   - NSAppleEventsUsageDescription is present and non-empty (paste
//     synthesis uses Apple Events).
//   - NSHumanReadableCopyright references PolyForm Strict and the
//     commercial-license email (so Finder Get Info surfaces the
//     correct license info).
//
// This complements VersionConsistencyTests, which verifies the
// CFBundleShortVersionString matches Version.swift; here we cover
// every OTHER required Info.plist key.

enum InfoPlistTests {

    static func registerAll() {
        TestRegistry.register("InfoPlist/bundleIdentifierMatchesSwift", bundleIdentifierMatchesSwift)
        TestRegistry.register("InfoPlist/packageTypeIsAPPL", packageTypeIsAPPL)
        TestRegistry.register("InfoPlist/principalClassIsNSApplication", principalClassIsNSApplication)
        TestRegistry.register("InfoPlist/isMenuBarOnlyApp", isMenuBarOnlyApp)
        TestRegistry.register("InfoPlist/minimumSystemVersionIs13", minimumSystemVersionIs13)
        TestRegistry.register("InfoPlist/hasAppleEventsUsageDescription", hasAppleEventsUsageDescription)
        TestRegistry.register("InfoPlist/copyrightReferencesPolyFormStrictAndCommercialEmail", copyrightReferencesPolyFormStrictAndCommercialEmail)
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/Tests/MultipasteCoreTests
            .deletingLastPathComponent()   // …/Tests
            .deletingLastPathComponent()   // …/<packageRoot>
    }

    // Parse Info.plist via PropertyListSerialization (built-in,
    // schema-aware) so we don't have to grep for raw XML.
    private static func parseInfoPlist(file: StaticString = #file, line: UInt = #line) throws -> [String: Any] {
        let url = packageRoot.appendingPathComponent("Resources/Info.plist")
        guard let data = try? Data(contentsOf: url) else {
            throw TestFailure(message: "Failed to read Resources/Info.plist",
                              file: file, line: line)
        }
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: &format) as? [String: Any] else {
            throw TestFailure(message: "Info.plist did not parse as [String: Any]",
                              file: file, line: line)
        }
        return plist
    }

    private static func require<T>(_ plist: [String: Any], _ key: String,
                                   as type: T.Type,
                                   file: StaticString = #file, line: UInt = #line) throws -> T {
        guard let value = plist[key] else {
            throw TestFailure(message: "Info.plist missing required key '\(key)'",
                              file: file, line: line)
        }
        guard let typed = value as? T else {
            throw TestFailure(
                message: "Info.plist key '\(key)' has unexpected type — expected \(T.self), got \(Swift.type(of: value))",
                file: file, line: line)
        }
        return typed
    }

    // ----- CFBundleIdentifier ⇔ Swift -----

    // If these drift, macOS treats two installations as different apps —
    // breaks Accessibility grants, Login Item registrations, preferences,
    // launch agents, everything that uses the bundle ID as the key.
    static func bundleIdentifierMatchesSwift() throws {
        let plist = try parseInfoPlist()
        let plistBundleID = try require(plist, "CFBundleIdentifier", as: String.self)
        let swift = try String(contentsOf:
            packageRoot.appendingPathComponent("Sources/MultipasteCore/Version.swift"),
                               encoding: .utf8)
        guard let range = swift.range(of: #"bundleIdentifier = "([^"]+)""#,
                                       options: .regularExpression) else {
            throw TestFailure(
                message: "Could not find `bundleIdentifier = \"...\"` in Version.swift",
                file: #file, line: #line)
        }
        let match = String(swift[range])
        let swiftBundleID = match
            .replacingOccurrences(of: "bundleIdentifier = \"", with: "")
            .replacingOccurrences(of: "\"", with: "")
        try expectEqual(plistBundleID, swiftBundleID,
                        "Info.plist CFBundleIdentifier (\(plistBundleID)) doesn't match Swift's MultipasteVersion.bundleIdentifier (\(swiftBundleID))")
    }

    // ----- CFBundlePackageType -----

    static func packageTypeIsAPPL() throws {
        let plist = try parseInfoPlist()
        let value = try require(plist, "CFBundlePackageType", as: String.self)
        try expectEqual(value, "APPL",
                        "Info.plist CFBundlePackageType must be 'APPL' (macOS treats the bundle as an app)")
    }

    // ----- NSPrincipalClass -----

    static func principalClassIsNSApplication() throws {
        let plist = try parseInfoPlist()
        let value = try require(plist, "NSPrincipalClass", as: String.self)
        try expectEqual(value, "NSApplication",
                        "Info.plist NSPrincipalClass must be 'NSApplication' for an AppKit app")
    }

    // ----- LSUIElement (menubar-only, no Dock icon) -----

    static func isMenuBarOnlyApp() throws {
        let plist = try parseInfoPlist()
        // LSUIElement can be either a Bool or the strings "1"/"YES".
        // PropertyListSerialization parses XML <true/> as Bool.
        if let asBool = plist["LSUIElement"] as? Bool {
            try expect(asBool, "Info.plist LSUIElement must be true (Multipaste is a menubar-only app; without this the Dock icon appears and ⌘W behavior is wrong)")
        } else if let asString = plist["LSUIElement"] as? String {
            try expect(asString == "1" || asString.uppercased() == "YES",
                       "Info.plist LSUIElement must be true; got string '\(asString)'")
        } else {
            throw TestFailure(message: "Info.plist LSUIElement missing or wrong type",
                              file: #file, line: #line)
        }
    }

    // ----- LSMinimumSystemVersion -----

    // Bumping this drops users on older macOS. v2.0.1's audit confirmed
    // the codebase is 13.0-compatible (no `if #available(macOS 14...)`
    // or later). If you intentionally raise this floor, update both the
    // plist value AND this assertion AND SECURITY.md's supported-
    // versions table.
    static func minimumSystemVersionIs13() throws {
        let plist = try parseInfoPlist()
        let value = try require(plist, "LSMinimumSystemVersion", as: String.self)
        try expectEqual(value, "13.0",
                        "Info.plist LSMinimumSystemVersion must be 13.0 (Ventura) unless you've deliberately raised the floor")
    }

    // ----- NSAppleEventsUsageDescription -----

    // macOS displays this string when the app first uses Apple Events.
    // A missing key or empty string can produce silent permission denials.
    static func hasAppleEventsUsageDescription() throws {
        let plist = try parseInfoPlist()
        let value = try require(plist, "NSAppleEventsUsageDescription", as: String.self)
        try expect(!value.isEmpty,
                   "Info.plist NSAppleEventsUsageDescription must be a non-empty string (macOS displays it on first Apple Events use)")
        try expect(value.contains("Multipaste") || value.lowercased().contains("paste"),
                   "Info.plist NSAppleEventsUsageDescription should mention Multipaste or paste so the system prompt is intelligible")
    }

    // ----- NSHumanReadableCopyright -----

    // Surfaces in Finder → Get Info. Should reflect the current
    // licensing (PolyForm Strict 1.0.0) and the commercial-license
    // email so anyone right-clicking on Multipaste.app and choosing
    // "Get Info" finds the right contact.
    static func copyrightReferencesPolyFormStrictAndCommercialEmail() throws {
        let plist = try parseInfoPlist()
        let value = try require(plist, "NSHumanReadableCopyright", as: String.self)
        try expect(value.contains("Rohin Agrawal"),
                   "Info.plist NSHumanReadableCopyright should contain the copyright holder name")
        try expect(value.contains("PolyForm Strict"),
                   "Info.plist NSHumanReadableCopyright should mention the PolyForm Strict license")
        try expect(value.contains("rohin.agrawal@gmail.com"),
                   "Info.plist NSHumanReadableCopyright should include the commercial-licensing email")
    }
}
