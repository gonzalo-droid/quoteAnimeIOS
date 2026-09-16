import Foundation

/// Streak across ALL habits combined — a day counts if any habit was completed that day.
/// Backs the "racha global" shown above the habit list, distinct from each habit's own streak.
struct GetGlobalStreakUseCase {
    private let repository: HabitRepository
    private let calculateStreak: CalculateStreakUseCase

    init(repository: HabitRepository, calendar: Calendar = .current) {
        self.repository = repository
        self.calculateStreak = CalculateStreakUseCase(calendar: calendar)
    }

    /// `today` is a parameter rather than a `Date()` read inside, matching Android's
    /// `invoke(today: LocalDate)`. Reading the clock internally made the result impossible to
    /// pin in a test and made the streak depend on *when* the call happened to run relative to
    /// midnight.
    func execute(today: Date = Date()) async throws -> StreakState {
        let dates = try await repository.fetchAllCompletionDates()
        return calculateStreak.execute(dates: dates, today: today)
    }
}
