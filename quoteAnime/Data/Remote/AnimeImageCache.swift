import Foundation

/// Manages anime image URL resolution.
/// Fetched once per session from /imagenes, then provides stable (non-re-randomizing) URL selection per slug.
final class AnimeImageCache {
    private var allImages: [String: [String]] = [:]
    private var resolvedUrls: [String: String] = [:]

    func load(images: [String: [String]]) {
        allImages = images
    }

    /// Returns a stable URL for the given slug. Picks randomly once, then caches that choice.
    func resolve(slug: String?) -> String? {
        guard let slug, !slug.isEmpty else { return nil }
        if let cached = resolvedUrls[slug] { return cached }
        guard let urls = allImages[slug], !urls.isEmpty else { return nil }
        let chosen = urls.randomElement()!
        resolvedUrls[slug] = chosen
        return chosen
    }

    /// Resolves imageUrls for an array of quotes in-place.
    func resolveImages(for quotes: [Quote]) -> [Quote] {
        quotes.map { quote in
            var q = quote
            q.imageUrl = resolve(slug: q.animeSlug)
            return q
        }
    }
}
