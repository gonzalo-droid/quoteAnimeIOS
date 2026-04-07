import Foundation

struct ToggleFavoriteUseCase {
    private let repository: QuoteRepository

    init(repository: QuoteRepository) {
        self.repository = repository
    }

    func execute(_ quote: Quote) async throws {
        try await repository.toggleFavorite(quote)
    }
}
