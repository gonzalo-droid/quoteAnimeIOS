import Foundation
import UserNotifications

/// What the view models actually need from the reminder scheduler. Exists so they can be
/// tested without `UNUserNotificationCenter`, whose round trips are slow and whose behaviour
/// depends on the host app's notification authorisation.
protocol HabitReminderScheduling {
    /// Whether reminders can be delivered at all — prompts the first time. The editor calls it
    /// when the reminder switch is turned on, like Android's `POST_NOTIFICATIONS` launcher.
    func requestPermission() async -> Bool
    func schedule(habit: Habit) async
    func cancel(habitId: String) async
}

/// Per-habit local notifications, one per selected weekday (`UNCalendarNotificationTrigger`
/// repeats natively on a matching weekday when only `weekday`/`hour`/`minute` are set).
final class HabitReminderScheduler: HabitReminderScheduling {
    static let categoryIdentifier = "HABIT_REMINDER"
    static let markDoneActionIdentifier = "MARK_DONE_ACTION"

    /// Catalog key of the reminder body. Kept as a constant because it's looked up at delivery
    /// time, where the compiler can't extract it; `Localizable.xcstrings` carries it by hand.
    static let reminderBodyKey = "¿Ya completaste tu hábito de hoy?"

    private let center = UNUserNotificationCenter.current()

    static func registerCategory() {
        let markDone = UNNotificationAction(
            identifier: markDoneActionIdentifier,
            // Categories are registered on every launch, so the title follows the current language.
            title: String(localized: "Hecho", comment: "Notification action: mark the habit as done today"),
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

    func requestPermission() async -> Bool {
        await center.requestAppAuthorization()
    }

    func schedule(habit: Habit) async {
        await cancel(habitId: habit.id)
        guard habit.reminderEnabled, !habit.reminderWeekdays.isEmpty else { return }

        for weekday in habit.reminderWeekdays {
            let content = UNMutableNotificationContent()
            content.title = habit.title
            // Resolved when the notification is delivered, not when it's scheduled: these requests
            // repeat weekly for months, and the user may change the device language meanwhile.
            content.body = NSString.localizedUserNotificationString(
                forKey: Self.reminderBodyKey,
                arguments: nil
            )
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
