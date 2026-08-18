import Foundation

struct UnarchiveHabitUseCase {
    private let repository: HabitRepository

    init(repository: HabitRepository) {
        self.repository = repository
    }

    func execute(id: String) async throws {
        try await repository.unarchiveHabit(id: id)
    }
}
