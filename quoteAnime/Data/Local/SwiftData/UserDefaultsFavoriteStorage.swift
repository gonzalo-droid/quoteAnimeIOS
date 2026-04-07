import Foundation

/// Fallback favorite storage using UserDefaults for iOS 16 devices.
final class UserDefaultsFavoriteStorage: FavoriteStorageProtocol {
    private let key = "favorite_quotes_v1"
    private let defaults = UserDefaults.standard

    func insert(_ quote: Quote) throws {
        var favorites = loadAll()
        guard !favorites.contains(where: { $0.id == quote.id }) else { return }
        var fav = quote
        fav.isFavorite = true
        favorites.append(fav)
        try persist(favorites)
    }

    func delete(id: String) throws {
        var favorites = loadAll()
        favorites.removeAll { $0.id == id }
        try persist(favorites)
    }

    func fetchAll() throws -> [Quote] {
        loadAll()
    }

    func exists(id: String) throws -> Bool {
        loadAll().contains { $0.id == id }
    }

    // MARK: Private

    private func loadAll() -> [Quote] {
        guard let data = defaults.data(forKey: key),
              let quotes = try? JSONDecoder().decode([Quote].self, from: data) else {
            return []
        }
        return quotes
    }

    private func persist(_ quotes: [Quote]) throws {
        let data = try JSONEncoder().encode(quotes)
        defaults.set(data, forKey: key)
    }
}
