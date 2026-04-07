import Foundation

protocol QuoteRepository {
    func fetchAllQuotes() async throws -> [Quote]
    func fetchQuotesByAnime(_ anime: String) async throws -> [Quote]
    func toggleFavorite(_ quote: Quote) async throws
    func fetchFavorites() async throws -> [Quote]
    func isFavorite(id: String) async -> Bool
}
