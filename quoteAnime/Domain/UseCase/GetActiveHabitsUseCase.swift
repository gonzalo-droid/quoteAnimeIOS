import Foundation

struct GetActiveHabitsUseCase {
    private let repository: HabitRepository
    private let calculateStreak: CalculateStreakUseCase

    init(repository: HabitRepository, calendar: Calendar = .current) {
        self.repository = repository
        self.calculateStreak = CalculateStreakUseCase(calendar: calendar)
    }

    /// `today` is injected for the same reason as in `GetGlobalStreakUseCase`: each habit's
    /// streak depends on which day "today" is, and reading `Date()` inside made that impossible
    /// to pin in a test and non-deterministic around midnight.
    func execute(today: Date = Date()) async throws -> [HabitWithProgress] {
        let habits = try await repository.fetchActiveHabits()
        var result: [HabitWithProgress] = []
        result.reserveCapacity(habits.count)

        for habit in habits {
            let dates = try await repository.fetchCompletions(habitId: habit.id)
            let streak = calculateStreak.execute(dates: dates, today: today)
            result.append(HabitWithProgress(habit: habit, completions: Set(dates), streak: streak))
        }
        return result
    }
}
