import Foundation
@testable import MultipasteCore

enum PasteboardAugmenterTests {

    static func registerAll() {
        TestRegistry.register("PasteboardAugmenter/pathTextSingle", pathTextSingle)
        TestRegistry.register("PasteboardAugmenter/pathTextMultiple", pathTextMultiple)
        TestRegistry.register("PasteboardAugmenter/pathTextEmpty", pathTextEmpty)
        TestRegistry.register("PasteboardAugmenter/shouldAugmentNil", shouldAugmentNil)
        TestRegistry.register("PasteboardAugmenter/shouldAugmentEmpty", shouldAugmentEmpty)
        TestRegistry.register("PasteboardAugmenter/shouldAugmentWhitespaceOnly", shouldAugmentWhitespaceOnly)
        TestRegistry.register("PasteboardAugmenter/shouldNotAugmentRealText", shouldNotAugmentRealText)
    }

    static func pathTextSingle() throws {
        let url = URL(fileURLWithPath: "/Users/x/code/README.md")
        try expectEqual(
            PasteboardAugmenter.pathText(forFiles: [url]),
            "/Users/x/code/README.md"
        )
    }

    static func pathTextMultiple() throws {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/c.png"),
        ]
        try expectEqual(
            PasteboardAugmenter.pathText(forFiles: urls),
            "/tmp/a.txt\n/tmp/b.txt\n/tmp/c.png"
        )
    }

    static func pathTextEmpty() throws {
        try expectEqual(PasteboardAugmenter.pathText(forFiles: []), "")
    }

    static func shouldAugmentNil() throws {
        try expect(PasteboardAugmenter.shouldAugment(existing: nil),
                   "nil string → must augment")
    }

    static func shouldAugmentEmpty() throws {
        try expect(PasteboardAugmenter.shouldAugment(existing: ""),
                   "empty string → must augment")
    }

    static func shouldAugmentWhitespaceOnly() throws {
        try expect(PasteboardAugmenter.shouldAugment(existing: "   \n\t  "),
                   "whitespace-only → must augment")
    }

    static func shouldNotAugmentRealText() throws {
        try expect(!PasteboardAugmenter.shouldAugment(existing: "README.md"),
                   "filename string from Finder → respect it, don't clobber")
        try expect(!PasteboardAugmenter.shouldAugment(existing: "hello world"),
                   "actual text → don't touch")
    }
}
