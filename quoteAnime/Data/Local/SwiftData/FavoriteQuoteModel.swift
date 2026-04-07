import Foundation
import SwiftData

@available(iOS 17, *)
@Model
final class FavoriteQuoteModel {
    @Attribute(.unique) var id: String
    var quoteText: String
    var author: String
    var anime: String
    var savedAt: Date

    init(from quote: Quote) {
        self.id = quote.id
        self.quoteText = quote.quote
        self.author = quote.author
        self.anime = quote.anime
        self.savedAt = Date()
    }

    func toDomain() -> Quote {
        Quote(id: id, quote: quoteText, author: author, anime: anime, isFavorite: true)
    }
}
