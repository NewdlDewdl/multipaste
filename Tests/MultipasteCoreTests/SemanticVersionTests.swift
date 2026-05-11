import Foundation
@testable import MultipasteCore

enum SemanticVersionTests {

    static func registerAll() {
        TestRegistry.register("SemanticVersion/parsesBareSemver", parsesBareSemver)
        TestRegistry.register("SemanticVersion/parsesVPrefix", parsesVPrefix)
        TestRegistry.register("SemanticVersion/rejectsGarbage", rejectsGarbage)
        TestRegistry.register("SemanticVersion/rejectsTwoComponents", rejectsTwoComponents)
        TestRegistry.register("SemanticVersion/comparePatchBumps", comparePatchBumps)
        TestRegistry.register("SemanticVersion/compareMinorBumps", compareMinorBumps)
        TestRegistry.register("SemanticVersion/compareMajorBumps", compareMajorBumps)
        TestRegistry.register("SemanticVersion/compareDoubleDigitMinor", compareDoubleDigitMinor)
        TestRegistry.register("SemanticVersion/equalityIsExact", equalityIsExact)
        TestRegistry.register("SemanticVersion/descriptionRoundtrip", descriptionRoundtrip)
        TestRegistry.register("SemanticVersion/sortsCorrectly", sortsCorrectly)
    }

    static func parsesBareSemver() throws {
        let v = SemanticVersion("1.2.3")
        try expect(v != nil)
        try expectEqual(v?.major, 1)
        try expectEqual(v?.minor, 2)
        try expectEqual(v?.patch, 3)
    }

    static func parsesVPrefix() throws {
        let v = SemanticVersion("v1.2.3")
        try expect(v != nil)
        try expectEqual(v?.major, 1)
    }

    static func rejectsGarbage() throws {
        try expect(SemanticVersion("not a version") == nil)
        try expect(SemanticVersion("") == nil)
        try expect(SemanticVersion("v") == nil)
        try expect(SemanticVersion("1.2") == nil)
        try expect(SemanticVersion("1.2.x") == nil)
    }

    static func rejectsTwoComponents() throws {
        try expect(SemanticVersion("1.2") == nil)
    }

    static func comparePatchBumps() throws {
        let a = SemanticVersion("1.2.0")!
        let b = SemanticVersion("1.2.1")!
        try expect(a < b)
        try expect(!(b < a))
    }

    static func compareMinorBumps() throws {
        let a = SemanticVersion("1.2.10")!
        let b = SemanticVersion("1.3.0")!
        try expect(a < b)
    }

    static func compareMajorBumps() throws {
        let a = SemanticVersion("1.99.99")!
        let b = SemanticVersion("2.0.0")!
        try expect(a < b)
    }

    static func compareDoubleDigitMinor() throws {
        // String-based compare would erroneously place 1.10.0 before 1.2.0.
        // Numeric compare is the whole point.
        let a = SemanticVersion("1.2.0")!
        let b = SemanticVersion("1.10.0")!
        try expect(a < b)
    }

    static func equalityIsExact() throws {
        let a = SemanticVersion("1.2.3")!
        let b = SemanticVersion("v1.2.3")!
        try expectEqual(a, b)
    }

    static func descriptionRoundtrip() throws {
        let v = SemanticVersion("v3.14.159")!
        try expectEqual(v.description, "3.14.159")
        let back = SemanticVersion(v.description)
        try expectEqual(back, v)
    }

    static func sortsCorrectly() throws {
        let versions = ["1.0.0", "1.10.0", "1.2.0", "0.9.0", "2.0.1", "1.10.1"]
            .compactMap(SemanticVersion.init)
            .sorted()
            .map(\.description)
        try expectEqual(versions, ["0.9.0", "1.0.0", "1.2.0", "1.10.0", "1.10.1", "2.0.1"])
    }
}
