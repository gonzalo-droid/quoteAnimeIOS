import Foundation

struct GetArchivedHabitsUseCase {
    private let repository: HabitRepository
    private let calculateStreak = CalculateStreakUseCase()

    init(repository: HabitRepository) {
        self.repository = repository
    }

    func execute() async throws -> [HabitWithProgress] {
        let habits = try await repository.fetchArchivedHabits()
        var result: [HabitWithProgress] = []
        result.reserveCapacity(habits.count)

        for habit in habits {
            let dates = try await repository.fetchCompletions(habitId: habit.id)
            let streak = calculateStreak.execute(dates: dates, today: Date())
            result.append(HabitWithProgress(habit: habit, completions: Set(dates), streak: streak))
        }
        return result
    }
}
