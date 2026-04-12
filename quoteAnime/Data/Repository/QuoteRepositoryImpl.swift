import Foundation

final class QuoteRepositoryImpl: QuoteRepository {
    private let remoteDataSource: QuoteRemoteDataSource
    private let imagesDataSource: AnimeImagesRemoteDataSource
    private let favoriteStorage: FavoriteStorageProtocol
    private let imageCache = AnimeImageCache()
    private var cache: [Quote] = []
    private var imagesFetched = false

    init(
        remoteDataSource: QuoteRemoteDataSource,
        imagesDataSource: AnimeImagesRemoteDataSource,
        favoriteStorage: FavoriteStorageProtocol
    ) {
        self.remoteDataSource = remoteDataSource
        self.imagesDataSource = imagesDataSource
        self.favoriteStorage  = favoriteStorage
    }

    func fetchAllQuotes() async throws -> [Quote] {
        await preloadImagesIfNeeded()
        let dtos = try await remoteDataSource.fetchAllQuotes()
        let quotes: [Quote] = dtos.map { dto in
            var q = dto.toDomain()
            q.isFavorite = (try? favoriteStorage.exists(id: q.id)) ?? false
            q.imageUrl   = imageCache.resolve(slug: q.animeSlug)
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
        await preloadImagesIfNeeded()
        let favorites = try favoriteStorage.fetchAll()
        return favorites.map { quote in
            var q = quote
            q.imageUrl = imageCache.resolve(slug: q.animeSlug)
            return q
        }
    }

    func isFavorite(id: String) async -> Bool {
        (try? favoriteStorage.exists(id: id)) ?? false
    }

    // MARK: Private

    private func preloadImagesIfNeeded() async {
        guard !imagesFetched else { return }
        imagesFetched = true
        do {
            let images = try await imagesDataSource.fetchImages()
            imageCache.load(images: images)
        } catch {
            print("[QuoteRepositoryImpl] image preload failed: \(error)")
        }
    }
}
