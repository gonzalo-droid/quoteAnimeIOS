import Foundation

/// The "Hecho" button of a habit reminder — Android's `HabitReminderReceiver`.
///
/// It is an **idempotent "mark done", not a toggle**: if the user already marked today from the
/// app, tapping the notification's button must leave the day marked. Before this existed the
/// delegate called `ToggleHabitCompletionUseCase` directly, so a second "Hecho" *unmarked* the day.
/// A stale notification for a habit that was deleted or has ended does nothing, like Android's
/// `isActiveOn` guard; the rest of the validation stays in the use case.
struct HabitReminderDoneAction {
    private let repository: HabitRepository
    private let toggleHabitCompletion: ToggleHabitCompletionUseCase
    private let analytics: RoutineAnalytics
    private let calendar: Calendar

    init(
        repository: HabitRepository,
        toggleHabitCompletion: ToggleHabitCompletionUseCase,
        analytics: RoutineAnalytics,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.toggleHabitCompletion = toggleHabitCompletion
        self.analytics = analytics
        self.calendar = calendar
    }

    /// - Returns: true when this call is what marked the day.
    @discardableResult
    func execute(habitId: String, today: Date = Date()) async -> Bool {
        guard let habit = try? await repository.fetchHabit(id: habitId),
              habit.isActiveOn(today, calendar: calendar),
              (try? await repository.isCompleted(habitId: habitId, date: calendar.startOfDay(for: today))) == false,
              (try? await toggleHabitCompletion.execute(habitId: habitId, date: today, today: today)) == true
        else { return false }

        analytics.trackHabitCompleted(habitId: habitId, isRetroactive: false, source: .notification)
        return true
    }
}
