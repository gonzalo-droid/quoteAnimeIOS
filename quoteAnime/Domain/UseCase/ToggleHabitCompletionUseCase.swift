import Foundation

/// Why the three rejections are `Error`s and not a Swift `enum` result, the way Android
/// models them with `sealed interface ToggleCompletionResult`: every other use case in this
/// layer already signals failure by throwing a typed error (`CreateHabitError`,
/// `UpdateHabitError`), and every call site is already inside `try await`. A result enum here
/// would put two error idioms in one layer and force each caller to `switch` over a value it
/// only ever wants to ignore or surface. The success payload Android carries
/// (`Success(completed:)`) survives as the plain `Bool` this method returns.
enum ToggleCompletionError: Error, Equatable {
    case habitNotFound
    case futureDate
    case outsideHabitRange
}

/// Marks or unmarks a single day. Past days can be corrected; future days cannot be marked,
/// and days outside the habit's own start/end window are rejected so the completion rate stays
/// meaningful. Mirrors Android's `ToggleHabitCompletionUseCase`, including the order the three
/// guards run in (not found → future → out of range).
struct ToggleHabitCompletionUseCase {
    private let repository: HabitRepository
    private let calendar: Calendar

    /// The calendar is injectable for the same reason as in `CalculateStreakUseCase`: Android
    /// compares `LocalDate`s, so on iOS the calendar is what decides which day an instant
    /// belongs to.
    init(repository: HabitRepository, calendar: Calendar = .current) {
        self.repository = repository
        self.calendar = calendar
    }

    /// - Returns: the day's new completed state.
    @discardableResult
    func execute(habitId: String, date: Date, today: Date = Date()) async throws -> Bool {
        guard let habit = try await repository.fetchHabit(id: habitId) else {
            throw ToggleCompletionError.habitNotFound
        }

        let day = calendar.startOfDay(for: date)
        guard day <= calendar.startOfDay(for: today) else {
            throw ToggleCompletionError.futureDate
        }
        guard habit.isActiveOn(day, calendar: calendar) else {
            throw ToggleCompletionError.outsideHabitRange
        }

        let newValue = !(try await repository.isCompleted(habitId: habitId, date: day))
        try await repository.setCompletion(habitId: habitId, date: day, completed: newValue)
        return newValue
    }
}
