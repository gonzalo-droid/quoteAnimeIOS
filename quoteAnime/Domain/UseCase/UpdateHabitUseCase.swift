import Foundation

struct UpdateHabitUseCase {
    private let repository: HabitRepository

    init(repository: HabitRepository) {
        self.repository = repository
    }

    func execute(_ habit: Habit) async throws {
        try await repository.saveHabit(habit)
    }
}
