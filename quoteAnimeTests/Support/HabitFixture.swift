import Foundation
@testable import quoteAnime

enum HabitFixture {
    static func make(
        id: String = UUID().uuidString,
        title: String = "Meditar",
        iconKey: String = "leaf",
        colorIndex: Int = 0,
        startDate: Date = TestCalendar.day(-30),
        createdAt: Date = TestCalendar.day(-30)
    ) -> Habit {
        Habit(
            id: id,
            title: title,
            description: nil,
            iconKey: iconKey,
            colorIndex: colorIndex,
            startDate: startDate,
            templateId: nil,
            coverAnimeSlug: nil,
            createdAt: createdAt
        )
    }

    /// `count` distinct habits, ids "habit-0", "habit-1", …
    static func makeMany(_ count: Int) -> [Habit] {
        (0..<count).map { make(id: "habit-\($0)", title: "Hábito \($0)") }
    }
}
