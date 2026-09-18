import Foundation

struct Habit: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String?
    var iconKey: String
    var colorIndex: Int
    var startDate: Date
    /// Optional close date. `nil` means the habit runs indefinitely — same meaning as
    /// Android's `Habit.endDate`. Days after it are outside the active window and cannot
    /// be marked, so the completion rate stays meaningful.
    var endDate: Date?
    /// Set when created from a themed suggestion. Nil for custom habits.
    var templateId: String?
    /// The suggestion's `themeKey`, resolved to its cover by `HabitThemeImages` (the card and the
    /// editor's preview). Same field and values as Android's `Habit.coverAnimeSlug`.
    var coverAnimeSlug: String?
    /// Archived habits keep their full history but stop counting as active. Mirrors Android,
    /// where `isArchived` lives on the domain model too — on iOS it used to exist only on
    /// `HabitModel`, which made "restore" invisible to the domain layer.
    var isArchived: Bool = false
    let createdAt: Date
    var reminderEnabled: Bool = false
    /// `Calendar` weekday numbering: 1 = Sunday ... 7 = Saturday.
    var reminderWeekdays: Set<Int> = []
    var reminderHour: Int = 9
    var reminderMinute: Int = 0

    /// True when `date` falls inside the habit's active window. Mirrors Android's
    /// `isActiveOn`: `!date.isBefore(startDate) && (endDate == null || !date.isAfter(endDate))`.
    ///
    /// Android compares `LocalDate`s, which carry no time at all. On iOS every `Date` is an
    /// instant, so both sides are normalised to start-of-day first — otherwise a habit created
    /// today at 18:00 would reject a completion stamped 09:00 the same day, which Android
    /// accepts.
    func isActiveOn(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard day >= calendar.startOfDay(for: startDate) else { return false }
        guard let endDate else { return true }
        return day <= calendar.startOfDay(for: endDate)
    }

    /// Weekdays the reminder actually fires on: none when the reminder is off, and the reminder is
    /// off when there are no weekdays. Android keeps the same invariant from the other side
    /// (`reminderDays = if (reminderTime == null) emptySet() else reminderDays`), and its
    /// scheduler skips a habit with a time and no days. Saving "on" with zero days used to leave
    /// a switch that looked armed and scheduled nothing, so the use cases store that as "off".
    mutating func normaliseReminder() {
        if reminderEnabled, reminderWeekdays.isEmpty {
            reminderEnabled = false
        }
        if !reminderEnabled {
            reminderWeekdays = []
        }
    }
}
