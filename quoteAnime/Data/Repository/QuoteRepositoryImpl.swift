import Foundation

final class QuoteRepositoryImpl: QuoteRepository {
    private let remoteDataSource: QuoteRemoteDataSource
    private let favoriteStorage: FavoriteStorageProtocol
    private var cache: [Quote] = []

    init(remoteDataSource: QuoteRemoteDataSource, favoriteStorage: FavoriteStorageProtocol) {
        self.remoteDataSource = remoteDataSource
        self.favoriteStorage = favoriteStorage
    }

    func fetchAllQuotes() async throws -> [Quote] {
        let dtos = try await remoteDataSource.fetchAllQuotes()
        let quotes: [Quote] = dtos.map { dto in
            var q = dto.toDomain()
            q.isFavorite = (try? favoriteStorage.exists(id: q.id)) ?? false
            return q
        }
        cache = quotes
        return quotes
    }

    func fetchQuotesByAnime(_ anime: String) async throws -> [Quote] {
        let all = try await fetchAllQuotes()
        return all.filter { $0.anime == anime }
    }

    func toggleFavorite(_ quote: Quote) async throws {
        let wasFavorite = (try? favoriteStorage.exists(id: quote.id)) ?? false
        if wasFavorite {
            try favoriteStorage.delete(id: quote.id)
        } else {
            try favoriteStorage.insert(quote)
        }
        if let idx = cache.firstIndex(where: { $0.id == quote.id }) {
            cache[idx].isFavorite = !wasFavorite
        }
    }

    func fetchFavorites() async throws -> [Quote] {
        try favoriteStorage.fetchAll()
    }

    func isFavorite(id: String) async -> Bool {
        (try? favoriteStorage.exists(id: id)) ?? false
    }
}
