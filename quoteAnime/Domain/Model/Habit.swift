import Foundation

struct Habit: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String?
    var iconKey: String
    var colorIndex: Int
    var startDate: Date
    /// Set when created from a themed suggestion — resolves to that template's cover image
    /// and description in the editor. Nil for custom habits.
    var templateId: String?
    var coverAnimeSlug: String?
    let createdAt: Date
    var reminderEnabled: Bool = false
    /// `Calendar` weekday numbering: 1 = Sunday ... 7 = Saturday.
    var reminderWeekdays: Set<Int> = []
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
}
