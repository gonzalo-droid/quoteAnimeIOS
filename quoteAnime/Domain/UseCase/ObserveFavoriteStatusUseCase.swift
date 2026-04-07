import Foundation

struct ObserveFavoriteStatusUseCase {
    private let repository: QuoteRepository

    init(repository: QuoteRepository) {
        self.repository = repository
    }

    func execute(id: String) async -> Bool {
        await repository.isFavorite(id: id)
    }
}
