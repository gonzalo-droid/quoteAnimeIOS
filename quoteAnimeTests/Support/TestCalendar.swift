import Foundation
import Testing
@testable import quoteAnime

/// A calendar pinned to a fixed timezone so day boundaries are deterministic regardless of
/// where the test runs. Android's use cases work on `LocalDate` and never face this; on iOS
/// every `Date` is an instant, so the calendar decides which day it lands on.
enum TestCalendar {
    static let timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!

    static var fixed: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "es_AR")
        return calendar
    }

    /// A stable reference "today": 2026-03-15 at noon local time. Noon keeps the fixture far
    /// from both midnight boundaries so a DST shift can't move it into the neighbouring day.
    static let today: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 15
        components.hour = 12
        return fixed.date(from: components)!
    }()

    /// `offset` days away from `today`, at noon local time.
    static func day(_ offset: Int) -> Date {
        fixed.date(byAdding: .day, value: offset, to: today)!
    }

    /// A specific wall-clock time on the day `offset` days from `today`.
    static func day(_ offset: Int, hour: Int, minute: Int = 0) -> Date {
        let start = fixed.startOfDay(for: day(offset))
        return fixed.date(byAdding: DateComponents(hour: hour, minute: minute), to: start)!
    }
}

/// One row of the streak table. Offsets are relative to `TestCalendar.today`, so `0` is today
/// and `-1` is yesterday.
struct StreakScenario: CustomTestStringConvertible {
    let label: String
    let dayOffsets: [Int]
    let expectedCurrent: Int
    let expectedBest: Int
    let expectedCompletedToday: Bool

    var dates: [Date] { dayOffsets.map { TestCalendar.day($0) } }
    var testDescription: String { label }
}
