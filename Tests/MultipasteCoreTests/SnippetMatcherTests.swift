import Foundation
@testable import MultipasteCore

enum SnippetMatcherTests {

    static func registerAll() {
        TestRegistry.register("SnippetMatcher/noMatchEmptyBuffer", noMatchEmptyBuffer)
        TestRegistry.register("SnippetMatcher/noMatchNoTerminator", noMatchNoTerminator)
        TestRegistry.register("SnippetMatcher/matchesTriggerEndingWithSpace", matchesTriggerEndingWithSpace)
        TestRegistry.register("SnippetMatcher/matchesTriggerEndingWithTab", matchesTriggerEndingWithTab)
        TestRegistry.register("SnippetMatcher/matchesTriggerEndingWithReturn", matchesTriggerEndingWithReturn)
        TestRegistry.register("SnippetMatcher/picksLongestTriggerOnAmbiguity", picksLongestTriggerOnAmbiguity)
        TestRegistry.register("SnippetMatcher/ignoresUnpinnedItems", ignoresUnpinnedItems)
        TestRegistry.register("SnippetMatcher/ignoresEmptyTrigger", ignoresEmptyTrigger)
        TestRegistry.register("SnippetMatcher/noFalsePositiveOnSubstring", noFalsePositiveOnSubstring)
        TestRegistry.register("SnippetMatcher/triggerAtStartOfBuffer", triggerAtStartOfBuffer)
        TestRegistry.register("SnippetMatcher/charsToDeleteEqualsTriggerPlusTerminator", charsToDeleteEqualsTriggerPlusTerminator)
    }

    private static func snippet(_ trigger: String, body: String, pinned: Bool = true) -> ClipboardItem {
        var item = ClipboardItem.text(body)
        item.pinned = pinned
        item.trigger = trigger
        return item
    }

    static func noMatchEmptyBuffer() throws {
        let result = SnippetMatcher.match(buffer: "", snippets: [snippet(";x", body: "expanded")])
        try expect(result == nil)
    }

    static func noMatchNoTerminator() throws {
        let result = SnippetMatcher.match(buffer: ";addr", snippets: [snippet(";addr", body: "123 Main")])
        try expect(result == nil, "match requires terminator (space/tab/enter) at end")
    }

    static func matchesTriggerEndingWithSpace() throws {
        let items = [snippet(";addr", body: "123 Main St")]
        let r = SnippetMatcher.match(buffer: ";addr ", snippets: items)
        try expect(r != nil)
        try expectEqual(r?.snippet.trigger, ";addr")
        try expectEqual(r?.charsToDelete, 6) // 5 trigger + 1 terminator
    }

    static func matchesTriggerEndingWithTab() throws {
        let items = [snippet(";sig", body: "best, R")]
        let r = SnippetMatcher.match(buffer: ";sig\t", snippets: items)
        try expectEqual(r?.snippet.trigger, ";sig")
    }

    static func matchesTriggerEndingWithReturn() throws {
        let items = [snippet(";sig", body: "best, R")]
        let r = SnippetMatcher.match(buffer: ";sig\n", snippets: items)
        try expectEqual(r?.snippet.trigger, ";sig")
    }

    static func picksLongestTriggerOnAmbiguity() throws {
        // Two triggers where one is a suffix of the other; longest wins so
        // ";email" doesn't get eaten by ";m".
        let items = [
            snippet(";m", body: "short"),
            snippet(";email", body: "long@example.com"),
        ]
        let r = SnippetMatcher.match(buffer: "hello ;email ", snippets: items)
        try expectEqual(r?.snippet.trigger, ";email")
    }

    static func ignoresUnpinnedItems() throws {
        let items = [snippet(";x", body: "unpinned", pinned: false)]
        let r = SnippetMatcher.match(buffer: ";x ", snippets: items)
        try expect(r == nil, "unpinned items must never fire snippets")
    }

    static func ignoresEmptyTrigger() throws {
        let items = [snippet("", body: "noop")]
        let r = SnippetMatcher.match(buffer: " ", snippets: items)
        try expect(r == nil)
    }

    static func noFalsePositiveOnSubstring() throws {
        // ";addr" should NOT match when the buffer is "x;addrr " — the
        // suffix before terminator isn't exactly the trigger.
        let items = [snippet(";addr", body: "x")]
        let r = SnippetMatcher.match(buffer: "x;addrr ", snippets: items)
        try expect(r == nil)
    }

    static func triggerAtStartOfBuffer() throws {
        let items = [snippet(";x", body: "y")]
        let r = SnippetMatcher.match(buffer: ";x ", snippets: items)
        try expectEqual(r?.snippet.trigger, ";x")
        try expectEqual(r?.charsToDelete, 3)
    }

    static func charsToDeleteEqualsTriggerPlusTerminator() throws {
        let items = [snippet("abc", body: "ABC")]
        let r = SnippetMatcher.match(buffer: "hello abc ", snippets: items)
        try expectEqual(r?.charsToDelete, 4) // "abc" + " "
    }
}
