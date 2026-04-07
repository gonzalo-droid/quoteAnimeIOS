import Foundation

/// Abstraction over local favorite-quote storage.
/// iOS 17+ uses SwiftData (FavoriteQuoteDAO); iOS 16 uses UserDefaults (UserDefaultsFavoriteStorage).
protocol FavoriteStorageProtocol {
    func insert(_ quote: Quote) throws
    func delete(id: String) throws
    func fetchAll() throws -> [Quote]
    func exists(id: String) throws -> Bool
}
