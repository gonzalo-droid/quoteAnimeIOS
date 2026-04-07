import Foundation
import SwiftData

@available(iOS 17, *)
final class FavoriteQuoteDAO: FavoriteStorageProtocol {
    private let context: ModelContext

    init(modelContext: ModelContext) {
        self.context = modelContext
    }

    func insert(_ quote: Quote) throws {
        let model = FavoriteQuoteModel(from: quote)
        context.insert(model)
        try context.save()
    }

    func delete(id: String) throws {
        let descriptor = FetchDescriptor<FavoriteQuoteModel>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }

    func fetchAll() throws -> [Quote] {
        let descriptor = FetchDescriptor<FavoriteQuoteModel>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func exists(id: String) throws -> Bool {
        let descriptor = FetchDescriptor<FavoriteQuoteModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetchCount(descriptor) > 0
    }
}
