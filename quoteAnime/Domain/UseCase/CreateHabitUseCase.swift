import Foundation

enum CreateHabitError: Error, Equatable {
    /// Carries the limit that was hit, so the UI can name it — mirrors Android's
    /// `CreateHabitResult.LimitReached(max)`.
    case habitLimitReached(max: Int)
    case blankTitle
    case invalidDateRange
}

/// The single gate point for validation and the free-tier active-habit cap, mirroring
/// Android's `CreateHabitUseCase`.
///
/// Android builds the `Habit` itself from loose parameters; iOS receives an already-built one
/// (the editor owns the id and `createdAt`). The normalisation Android does while building —
/// trimming the title, dropping an empty description, clearing reminder days when there is no
/// reminder — is therefore applied here to the incoming value instead, and the normalised
/// habit is what gets saved and returned.
struct CreateHabitUseCase {
    private let repository: HabitRepository
    private let premiumGate: PremiumGate
    private let calendar: Calendar

    init(repository: HabitRepository, premiumGate: PremiumGate, calendar: Calendar = .current) {
        self.repository = repository
        self.premiumGate = premiumGate
        self.calendar = calendar
    }

    @discardableResult
    func execute(_ habit: Habit) async throws -> Habit {
        let clean = try normalised(habit)

        let max = premiumGate.maxActiveHabits
        let activeCount = try await repository.countActiveHabits()
        guard activeCount < max else {
            throw CreateHabitError.habitLimitReached(max: max)
        }

        try await repository.saveHabit(clean)
        return clean
    }

    /// Validation + normalisation, in Android's order: blank title first, then date range.
    private func normalised(_ habit: Habit) throws -> Habit {
        var clean = habit

        clean.title = habit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.title.isEmpty else { throw CreateHabitError.blankTitle }

        if let endDate = habit.endDate,
           calendar.startOfDay(for: endDate) < calendar.startOfDay(for: habit.startDate) {
            throw CreateHabitError.invalidDateRange
        }

        let trimmedDescription = habit.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.description = (trimmedDescription?.isEmpty ?? true) ? nil : trimmedDescription

        // Android: `reminderDays = if (reminderTime == null) emptySet() else reminderDays`.
        // iOS models "has a reminder" as `reminderEnabled` rather than a nullable time.
        if !habit.reminderEnabled {
            clean.reminderWeekdays = []
        }

        return clean
    }
}
