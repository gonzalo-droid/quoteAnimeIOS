import Foundation

struct ToggleHabitCompletionUseCase {
    private let repository: HabitRepository

    init(repository: HabitRepository) {
        self.repository = repository
    }

    func execute(habitId: String, date: Date) async throws {
        let alreadyCompleted = try await repository.isCompleted(habitId: habitId, date: date)
        try await repository.setCompletion(habitId: habitId, date: date, completed: !alreadyCompleted)
    }
}
