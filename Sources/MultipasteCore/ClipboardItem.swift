import Foundation
import CryptoKit

/// A single entry in clipboard history.
///
/// Items are immutable except for `pinned`. Equality is by `id`; deduplication
/// uses `contentHash`, which is content-derived and stable across processes.
public struct ClipboardItem: Identifiable, Codable, Equatable {

    public enum Kind: Codable, Equatable {
        case text(String)
        case fileURLs([URL])
        case rtf(rtfData: Data, plain: String)
        case image(pngData: Data, width: Int, height: Int)
    }

    public let id: UUID
    public let kind: Kind
    public let timestamp: Date
    public var pinned: Bool
    public let contentHash: String
    public let preview: String
    public let kindLabel: String

    /// Optional snippet trigger. When set AND the item is pinned, typing
    /// `<trigger><space|tab|enter>` anywhere on the system expands the
    /// trigger into this item's content (via `SnippetEngine`).
    public var trigger: String?

    public init(id: UUID, kind: Kind, timestamp: Date, pinned: Bool,
                contentHash: String, preview: String, kindLabel: String,
                trigger: String? = nil) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.pinned = pinned
        self.contentHash = contentHash
        self.preview = preview
        self.kindLabel = kindLabel
        self.trigger = trigger
    }

    // Custom Codable so legacy JSON (v1.0.0, no `trigger` key) still decodes.
    enum CodingKeys: String, CodingKey {
        case id, kind, timestamp, pinned, contentHash, preview, kindLabel, trigger
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.kind = try c.decode(Kind.self, forKey: .kind)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.pinned = try c.decode(Bool.self, forKey: .pinned)
        self.contentHash = try c.decode(String.self, forKey: .contentHash)
        self.preview = try c.decode(String.self, forKey: .preview)
        self.kindLabel = try c.decode(String.self, forKey: .kindLabel)
        self.trigger = try c.decodeIfPresent(String.self, forKey: .trigger)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(pinned, forKey: .pinned)
        try c.encode(contentHash, forKey: .contentHash)
        try c.encode(preview, forKey: .preview)
        try c.encode(kindLabel, forKey: .kindLabel)
        try c.encodeIfPresent(trigger, forKey: .trigger)
    }

    // MARK: - Factories

    public static func text(_ s: String) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .text(s),
            timestamp: Date(),
            pinned: false,
            contentHash: "text:" + Self.sha256(s),
            preview: Self.makePreview(s),
            kindLabel: "Text"
        )
    }

    public static func fileURLs(_ urls: [URL]) -> ClipboardItem {
        let names = urls.map(\.lastPathComponent).joined(separator: ", ")
        let hashSource = urls.map(\.path).joined(separator: "\n")
        return ClipboardItem(
            id: UUID(),
            kind: .fileURLs(urls),
            timestamp: Date(),
            pinned: false,
            contentHash: "files:" + Self.sha256(hashSource),
            preview: names.isEmpty ? "(no files)" : names,
            kindLabel: "Files"
        )
    }

    public static func rtf(rtfData: Data, plain: String) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .rtf(rtfData: rtfData, plain: plain),
            timestamp: Date(),
            pinned: false,
            contentHash: "rtf:" + Self.sha256(plain),
            preview: Self.makePreview(plain),
            kindLabel: "Rich Text"
        )
    }

    public static func image(pngData: Data, width: Int, height: Int) -> ClipboardItem {
        let digest = SHA256.hash(data: pngData).map { String(format: "%02x", $0) }.joined()
        return ClipboardItem(
            id: UUID(),
            kind: .image(pngData: pngData, width: width, height: height),
            timestamp: Date(),
            pinned: false,
            contentHash: "image:" + digest,
            preview: "Image (\(width)×\(height), \(formatBytes(pngData.count)))",
            kindLabel: "Image"
        )
    }

    // MARK: - Helpers

    /// SHA-256 of UTF-8 bytes, lowercase hex.
    private static func sha256(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Trim leading/trailing whitespace; truncate to 240 chars; collapse
    /// internal newlines to a single space for compact display. An empty
    /// payload becomes "(empty)" so the picker still has something to show.
    static func makePreview(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "(empty)" }
        let cap = 240
        if trimmed.count > cap { return String(trimmed.prefix(cap)) }
        return trimmed
    }

    private static func formatBytes(_ count: Int) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(count))
    }

    // MARK: - Equatable (by id)

    public static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
}
