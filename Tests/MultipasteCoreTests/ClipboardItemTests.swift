import Foundation
@testable import MultipasteCore

enum ClipboardItemTests {

    static func registerAll() {
        TestRegistry.register("ClipboardItem/textItemHashIsContentBased", textItemHashIsContentBased)
        TestRegistry.register("ClipboardItem/previewTrimsAndTruncates", previewTrimsAndTruncates)
        TestRegistry.register("ClipboardItem/previewForEmptyStringIsPlaceholder", previewForEmptyStringIsPlaceholder)
        TestRegistry.register("ClipboardItem/kindLabelForText", kindLabelForText)
        TestRegistry.register("ClipboardItem/fileURLItem", fileURLItem)
        TestRegistry.register("ClipboardItem/codableRoundtripText", codableRoundtripText)
        TestRegistry.register("ClipboardItem/codableRoundtripFileURLs", codableRoundtripFileURLs)
        TestRegistry.register("ClipboardItem/idIsUnique", idIsUnique)
        TestRegistry.register("ClipboardItem/triggerDefaultsToNil", triggerDefaultsToNil)
        TestRegistry.register("ClipboardItem/triggerSurvivesCodableRoundtrip", triggerSurvivesCodableRoundtrip)
        TestRegistry.register("ClipboardItem/decodesLegacyJSONWithoutTrigger", decodesLegacyJSONWithoutTrigger)
    }

    static func textItemHashIsContentBased() throws {
        let a = ClipboardItem.text("hello world")
        let b = ClipboardItem.text("hello world")
        let c = ClipboardItem.text("goodbye")
        try expectEqual(a.contentHash, b.contentHash)
        try expectNotEqual(a.contentHash, c.contentHash)
    }

    static func previewTrimsAndTruncates() throws {
        let long = String(repeating: "abcd", count: 200)
        let item = ClipboardItem.text("   \n\t" + long + "\n  ")
        try expect(!item.preview.hasPrefix(" "))
        try expect(!item.preview.hasPrefix("\n"))
        try expect(item.preview.count <= 240, "preview should be truncated; got length \(item.preview.count)")
    }

    static func previewForEmptyStringIsPlaceholder() throws {
        try expectEqual(ClipboardItem.text("").preview, "(empty)")
    }

    static func kindLabelForText() throws {
        try expectEqual(ClipboardItem.text("hi").kindLabel, "Text")
    }

    static func fileURLItem() throws {
        let urls = [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")]
        let item = ClipboardItem.fileURLs(urls)
        try expect(item.preview.contains("a.txt"))
        try expect(item.preview.contains("b.txt"))
        try expectEqual(item.kindLabel, "Files")
    }

    static func codableRoundtripText() throws {
        let original = ClipboardItem.text("round trip")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        try expectEqual(decoded.contentHash, original.contentHash)
        try expectEqual(decoded.preview, original.preview)
    }

    static func codableRoundtripFileURLs() throws {
        let urls = [URL(fileURLWithPath: "/tmp/x.png")]
        let original = ClipboardItem.fileURLs(urls)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        try expectEqual(decoded.contentHash, original.contentHash)
    }

    static func idIsUnique() throws {
        let a = ClipboardItem.text("same")
        let b = ClipboardItem.text("same")
        try expectNotEqual(a.id, b.id, "two captures of same content must still have distinct IDs")
        try expectEqual(a.contentHash, b.contentHash, "...but the same content hash for dedup")
    }

    static func triggerDefaultsToNil() throws {
        let item = ClipboardItem.text("hello")
        try expect(item.trigger == nil, "fresh items must not carry a snippet trigger")
    }

    static func triggerSurvivesCodableRoundtrip() throws {
        var item = ClipboardItem.text("home address")
        item.trigger = ";addr"
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        try expectEqual(decoded.trigger, ";addr")
    }

    static func decodesLegacyJSONWithoutTrigger() throws {
        // Format produced by v1.0.0 — no `trigger` key. Decoding must succeed
        // and the property must default to nil.
        let json = """
        {
          "id": "F3A72271-1CAC-424F-A9FA-1079B4ACEE1B",
          "kind": { "text": { "_0": "legacy" } },
          "timestamp": 800200687.772313,
          "pinned": false,
          "contentHash": "text:abc",
          "preview": "legacy",
          "kindLabel": "Text"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: json)
        try expectEqual(decoded.preview, "legacy")
        try expect(decoded.trigger == nil)
    }
}
