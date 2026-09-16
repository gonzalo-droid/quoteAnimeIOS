import Foundation
@testable import quoteAnime

enum HabitFixture {
    static func make(
        id: String = UUID().uuidString,
        title: String = "Meditar",
        description: String? = nil,
        iconKey: String = "leaf",
        colorIndex: Int = 0,
        startDate: Date = TestCalendar.day(-30),
        endDate: Date? = nil,
        isArchived: Bool = false,
        createdAt: Date = TestCalendar.day(-30),
        reminderEnabled: Bool = false,
        reminderWeekdays: Set<Int> = []
    ) -> Habit {
        Habit(
            id: id,
            title: title,
            description: description,
            iconKey: iconKey,
            colorIndex: colorIndex,
            startDate: startDate,
            endDate: endDate,
            templateId: nil,
            coverAnimeSlug: nil,
            isArchived: isArchived,
            createdAt: createdAt,
            reminderEnabled: reminderEnabled,
            reminderWeekdays: reminderWeekdays
        )
    }

    /// `count` distinct habits, ids "habit-0", "habit-1", …
    static func makeMany(_ count: Int) -> [Habit] {
        (0..<count).map { make(id: "habit-\($0)", title: "Hábito \($0)") }
    }
}
