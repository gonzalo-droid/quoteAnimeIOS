import Foundation

struct GetFavoriteQuotesUseCase {
    private let repository: QuoteRepository

    init(repository: QuoteRepository) {
        self.repository = repository
    }

    func execute() async throws -> [Quote] {
        try await repository.fetchFavorites()
    }
}
