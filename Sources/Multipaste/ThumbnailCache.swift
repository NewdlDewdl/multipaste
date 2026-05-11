import AppKit
import MultipasteCore

/// In-memory thumbnail cache keyed by `contentHash`. PNG decoding shows up
/// on Instruments traces when the picker has many image items — caching
/// the decoded `NSImage` collapses re-renders to a dictionary lookup.
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private var cache: [String: NSImage] = [:]
    /// Soft cap. We trim oldest entries when this is exceeded.
    private let maxEntries = 64

    /// Returns a thumbnail-sized image for the given clipboard item, or nil
    /// if the item is not an image kind.
    func thumbnail(for item: ClipboardItem, edge: CGFloat = 32) -> NSImage? {
        guard case .image(let png, _, _) = item.kind else { return nil }
        if let cached = cache[item.contentHash] { return cached }

        guard let image = NSImage(data: png) else { return nil }
        let thumb = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            image.draw(in: rect,
                       from: .zero,
                       operation: .copy,
                       fraction: 1.0,
                       respectFlipped: true,
                       hints: [.interpolation: NSImageInterpolation.high.rawValue])
            return true
        }
        if cache.count >= maxEntries {
            // Drop ~25% to keep amortized cost low rather than churning every insert
            let dropCount = maxEntries / 4
            for key in Array(cache.keys.prefix(dropCount)) { cache.removeValue(forKey: key) }
        }
        cache[item.contentHash] = thumb
        return thumb
    }
}
