import Foundation

struct GetAllQuotesUseCase {
    private let repository: QuoteRepository

    init(repository: QuoteRepository) {
        self.repository = repository
    }

    func execute(filteredBy categoryIds: Set<String> = []) async throws -> [Quote] {
        Self.filtered(try await repository.fetchAllQuotes(), by: categoryIds)
    }

    /// The anime filter itself, so callers holding an already-fetched pool (Home passing its
    /// feed to the notification scheduler) apply exactly the same rule without a second fetch.
    /// An empty selection means "all animes", matching Android's `selectedCategoryIds`.
    static func filtered(_ quotes: [Quote], by categoryIds: Set<String>) -> [Quote] {
        guard !categoryIds.isEmpty else { return quotes }
        return quotes.filter { categoryIds.contains($0.anime) }
    }
}
