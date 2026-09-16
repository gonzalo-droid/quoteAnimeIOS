import Foundation
@testable import quoteAnime

/// Hand-written stand-in for `QuoteRepository`. Only the quote catalogue matters for the
/// anime-filter tests, so favourites are kept in memory and nothing touches Firebase.
final class FakeQuoteRepository: QuoteRepository {

    private(set) var quotes: [Quote]
    private(set) var favoriteIds: Set<String> = []
    /// How many times the catalogue was fetched — proves callers don't refetch needlessly.
    private(set) var fetchCount = 0
    /// When set, `fetchAllQuotes()` throws it instead of returning the catalogue.
    var fetchError: Error?

    init(quotes: [Quote] = []) {
        self.quotes = quotes
    }

    /// Builds a catalogue from `anime: quoteCount` pairs, ids being "<anime>-<n>".
    static func withCatalogue(_ catalogue: [(anime: String, count: Int)]) -> FakeQuoteRepository {
        var quotes: [Quote] = []
        for entry in catalogue {
            for index in 0..<entry.count {
                quotes.append(
                    Quote(
                        id: "\(entry.anime)-\(index)",
                        quote: "Frase \(index) de \(entry.anime)",
                        author: "Autor \(index)",
                        anime: entry.anime
                    )
                )
            }
        }
        return FakeQuoteRepository(quotes: quotes)
    }

    // MARK: QuoteRepository

    func fetchAllQuotes() async throws -> [Quote] {
        fetchCount += 1
        if let fetchError { throw fetchError }
        return quotes.map { quote in
            var copy = quote
            copy.isFavorite = favoriteIds.contains(quote.id)
            return copy
        }
    }

    func fetchQuotesByAnime(_ anime: String) async throws -> [Quote] {
        try await fetchAllQuotes().filter { $0.anime == anime }
    }

    func toggleFavorite(_ quote: Quote) async throws {
        if favoriteIds.contains(quote.id) {
            favoriteIds.remove(quote.id)
        } else {
            favoriteIds.insert(quote.id)
        }
    }

    func fetchFavorites() async throws -> [Quote] {
        try await fetchAllQuotes().filter { favoriteIds.contains($0.id) }
    }

    func isFavorite(id: String) async -> Bool { favoriteIds.contains(id) }
}

struct FakeQuoteRepositoryError: Error {}
