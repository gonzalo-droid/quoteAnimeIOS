import Foundation
import SwiftData

@available(iOS 17, *)
@Model
final class HabitModel {
    @Attribute(.unique) var id: String
    var title: String
    var habitDescription: String?
    var iconKey: String
    var colorIndex: Int
    var startDate: Date
    var templateId: String?
    var coverAnimeSlug: String?
    var createdAt: Date
    var isArchived: Bool
    var reminderEnabled: Bool
    /// Stored as `[Int]` rather than `Set<Int>` — plain arrays of primitives are the safest
    /// SwiftData-supported shape; order carries no meaning here.
    var reminderWeekdays: [Int]
    var reminderHour: Int
    var reminderMinute: Int

    init(from habit: Habit, isArchived: Bool = false) {
        self.id = habit.id
        self.title = habit.title
        self.habitDescription = habit.description
        self.iconKey = habit.iconKey
        self.colorIndex = habit.colorIndex
        self.startDate = habit.startDate
        self.templateId = habit.templateId
        self.coverAnimeSlug = habit.coverAnimeSlug
        self.createdAt = habit.createdAt
        self.isArchived = isArchived
        self.reminderEnabled = habit.reminderEnabled
        self.reminderWeekdays = Array(habit.reminderWeekdays)
        self.reminderHour = habit.reminderHour
        self.reminderMinute = habit.reminderMinute
    }

    func apply(_ habit: Habit) {
        self.title = habit.title
        self.habitDescription = habit.description
        self.iconKey = habit.iconKey
        self.colorIndex = habit.colorIndex
        self.startDate = habit.startDate
        self.templateId = habit.templateId
        self.coverAnimeSlug = habit.coverAnimeSlug
        self.reminderEnabled = habit.reminderEnabled
        self.reminderWeekdays = Array(habit.reminderWeekdays)
        self.reminderHour = habit.reminderHour
        self.reminderMinute = habit.reminderMinute
    }

    func toDomain() -> Habit {
        Habit(
            id: id,
            title: title,
            description: habitDescription,
            iconKey: iconKey,
            colorIndex: colorIndex,
            startDate: startDate,
            templateId: templateId,
            coverAnimeSlug: coverAnimeSlug,
            createdAt: createdAt,
            reminderEnabled: reminderEnabled,
            reminderWeekdays: Set(reminderWeekdays),
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
    }
}
