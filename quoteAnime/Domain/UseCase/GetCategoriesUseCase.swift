import Foundation

struct GetCategoriesUseCase {
    private let repository: QuoteRepository

    init(repository: QuoteRepository) {
        self.repository = repository
    }

    func execute() async throws -> [Category] {
        let quotes = try await repository.fetchAllQuotes()
        let uniqueAnimes = Array(Set(quotes.map { $0.anime })).sorted()
        return uniqueAnimes.map { Category(id: $0, name: $0) }
    }
}
