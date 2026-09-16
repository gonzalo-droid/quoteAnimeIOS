import Foundation
@testable import quoteAnime

/// Records what the view models asked for instead of talking to `UNUserNotificationCenter`,
/// whose round trips are slow enough to race a test and whose results depend on the host app's
/// notification authorisation.
final class FakeHabitReminderScheduler: HabitReminderScheduling {
    private(set) var scheduledHabitIds: [String] = []
    private(set) var cancelledHabitIds: [String] = []

    func schedule(habit: Habit) async {
        scheduledHabitIds.append(habit.id)
    }

    func cancel(habitId: String) async {
        cancelledHabitIds.append(habitId)
    }
}
