import Foundation

/// Streak across ALL habits combined — a day counts if any habit was completed that day.
/// Backs the "racha global" shown above the habit list, distinct from each habit's own streak.
struct GetGlobalStreakUseCase {
    private let repository: HabitRepository
    private let calculateStreak = CalculateStreakUseCase()

    init(repository: HabitRepository) {
        self.repository = repository
    }

    func execute() async throws -> StreakState {
        let dates = try await repository.fetchAllCompletionDates()
        return calculateStreak.execute(dates: dates, today: Date())
    }
}
