import Foundation

struct GetAllQuotesUseCase {
    private let repository: QuoteRepository

    init(repository: QuoteRepository) {
        self.repository = repository
    }

    func execute(filteredBy categoryIds: Set<String> = []) async throws -> [Quote] {
        let all = try await repository.fetchAllQuotes()
        guard !categoryIds.isEmpty else { return all }
        return all.filter { categoryIds.contains($0.anime) }
    }
}
