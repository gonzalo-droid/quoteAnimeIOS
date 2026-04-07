import Foundation

struct QuoteDTO: Codable {
    let id: String
    let quote: String
    let author: String
    let anime: String

    func toDomain() -> Quote {
        Quote(id: id, quote: quote, author: author, anime: anime)
    }
}
