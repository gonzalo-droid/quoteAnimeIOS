import Foundation

/// Pure date math, no UI — column-major GitHub-contribution-style grid. Mirrors Android's
/// `HeatmapGrid.kt` exactly: weeks always start Monday, and masking (future/out-of-range
/// days) is the caller's job, not this type's.
enum HeatmapGrid {
    static let rows = 7

    static func gridStart(today: Date, weeks: Int) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2 // Monday

        let anchor = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: today) ?? today
        let weekday = calendar.component(.weekday, from: anchor) // 1 = Sunday ... 7 = Saturday
        let daysSinceMonday = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: calendar.startOfDay(for: anchor)) ?? anchor
    }

    static func date(column: Int, row: Int, gridStart: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: column * rows + row, to: gridStart) ?? gridStart
    }
}
