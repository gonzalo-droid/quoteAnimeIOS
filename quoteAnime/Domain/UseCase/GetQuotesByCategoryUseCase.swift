import Foundation

struct GetQuotesByCategoryUseCase {
    private let repository: QuoteRepository

    init(repository: QuoteRepository) {
        self.repository = repository
    }

    func execute(anime: String) async throws -> [Quote] {
        try await repository.fetchQuotesByAnime(anime)
    }
}
