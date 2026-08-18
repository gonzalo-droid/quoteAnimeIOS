import Foundation
import UserNotifications

/// Per-habit local notifications, one per selected weekday (`UNCalendarNotificationTrigger`
/// repeats natively on a matching weekday when only `weekday`/`hour`/`minute` are set).
final class HabitReminderScheduler {
    static let categoryIdentifier = "HABIT_REMINDER"
    static let markDoneActionIdentifier = "MARK_DONE_ACTION"

    private let center = UNUserNotificationCenter.current()

    static func registerCategory() {
        let markDone = UNNotificationAction(
            identifier: markDoneActionIdentifier,
            title: "Hecho",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [markDone],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func schedule(habit: Habit) async {
        await cancel(habitId: habit.id)
        guard habit.reminderEnabled, !habit.reminderWeekdays.isEmpty else { return }

        for weekday in habit.reminderWeekdays {
            let content = UNMutableNotificationContent()
            content.title = habit.title
            content.body = "¿Ya completaste tu hábito de hoy?"
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            content.userInfo = ["habitId": habit.id]

            var comps = DateComponents()
            comps.weekday = weekday
            comps.hour = habit.reminderHour
            comps.minute = habit.reminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

            let request = UNNotificationRequest(
                identifier: Self.identifier(habitId: habit.id, weekday: weekday),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancel(habitId: String) async {
        let pending = await center.pendingNotificationRequests()
        let prefix = "habit_\(habitId)_"
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func identifier(habitId: String, weekday: Int) -> String {
        "habit_\(habitId)_wd\(weekday)"
    }
}
