import Foundation

struct GetRandomQuoteUseCase {
    private let repository: QuoteRepository

    init(repository: QuoteRepository) {
        self.repository = repository
    }

    func execute() async throws -> Quote? {
        let all = try await repository.fetchAllQuotes()
        return all.randomElement()
    }
}
