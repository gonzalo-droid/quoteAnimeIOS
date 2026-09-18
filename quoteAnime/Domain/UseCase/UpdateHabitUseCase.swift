import Foundation

enum UpdateHabitError: Error, Equatable {
    case habitNotFound
    case blankTitle
    case invalidDateRange
}

/// Mirrors Android's `UpdateHabitUseCase`: the habit must exist, the title must not be blank
/// and `endDate` must not precede `startDate`. The limit check deliberately does *not* run
/// here — editing an existing habit never adds one.
struct UpdateHabitUseCase {
    private let repository: HabitRepository
    private let calendar: Calendar

    init(repository: HabitRepository, calendar: Calendar = .current) {
        self.repository = repository
        self.calendar = calendar
    }

    @discardableResult
    func execute(_ habit: Habit) async throws -> Habit {
        guard try await repository.fetchHabit(id: habit.id) != nil else {
            throw UpdateHabitError.habitNotFound
        }

        var clean = habit
        clean.title = habit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.title.isEmpty else { throw UpdateHabitError.blankTitle }

        if let endDate = habit.endDate,
           calendar.startOfDay(for: endDate) < calendar.startOfDay(for: habit.startDate) {
            throw UpdateHabitError.invalidDateRange
        }

        let trimmedDescription = habit.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.description = (trimmedDescription?.isEmpty ?? true) ? nil : trimmedDescription
        clean.normaliseReminder()

        try await repository.saveHabit(clean)
        return clean
    }
}
