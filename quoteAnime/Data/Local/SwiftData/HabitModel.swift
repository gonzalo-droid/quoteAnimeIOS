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
    }

    func apply(_ habit: Habit) {
        self.title = habit.title
        self.habitDescription = habit.description
        self.iconKey = habit.iconKey
        self.colorIndex = habit.colorIndex
        self.startDate = habit.startDate
        self.templateId = habit.templateId
        self.coverAnimeSlug = habit.coverAnimeSlug
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
            createdAt: createdAt
        )
    }
}
