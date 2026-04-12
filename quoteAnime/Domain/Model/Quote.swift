import Foundation

struct Quote: Identifiable, Codable {
    let id: String
    let quote: String
    let author: String
    let anime: String
    let categories: [String]
    let animeSlug: String?
    var imageUrl: String?
    var isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case id, quote, author, anime, categories, animeSlug, isFavorite
        // imageUrl is intentionally excluded — resolved at runtime, never persisted
    }

    init(
        id: String,
        quote: String,
        author: String,
        anime: String,
        categories: [String] = [],
        animeSlug: String? = nil,
        imageUrl: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.quote = quote
        self.author = author
        self.anime = anime
        self.categories = categories
        self.animeSlug = animeSlug
        self.imageUrl = imageUrl
        self.isFavorite = isFavorite
    }
}

extension Quote: Hashable {
    static func == (lhs: Quote, rhs: Quote) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
