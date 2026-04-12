import Foundation

struct QuoteDTO: Codable {
    let id: String
    let quote: String
    let author: String
    let anime: String
    let categories: [String]
    let animeSlug: String?

    func toDomain() -> Quote {
        Quote(
            id: id,
            quote: quote,
            author: author,
            anime: anime,
            categories: categories,
            animeSlug: animeSlug
        )
    }

    /// Constructs a QuoteDTO from a Firebase dictionary.
    /// - `key`: parent node key used as id fallback when the object has no "id" field.
    init?(dict: [String: Any], key: String?) {
        guard
            let quote  = dict["quote"]  as? String,
            let author = dict["author"] as? String,
            let anime  = dict["anime"]  as? String
        else {
            return nil
        }
        self.id         = (dict["id"] as? String) ?? key ?? UUID().uuidString
        self.quote      = quote
        self.author     = author
        self.anime      = anime
        self.animeSlug  = dict["animeSlug"] as? String

        // categories can be a Firebase array (becomes [String]) or a dict with int keys
        if let arr = dict["categories"] as? [String] {
            self.categories = arr
        } else if let arrAny = dict["categories"] as? [Any] {
            self.categories = arrAny.compactMap { $0 as? String }
        } else {
            self.categories = []
        }
    }
}
