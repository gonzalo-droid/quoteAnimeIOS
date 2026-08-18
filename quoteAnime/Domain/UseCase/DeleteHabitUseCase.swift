import Foundation

struct DeleteHabitUseCase {
    private let repository: HabitRepository

    init(repository: HabitRepository) {
        self.repository = repository
    }

    func execute(id: String) async throws {
        try await repository.deleteHabit(id: id)
    }
}
