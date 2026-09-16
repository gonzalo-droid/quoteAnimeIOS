import Foundation

/// Pure geometry of a classic month calendar, mirroring Android's `CalendarMonthGrid.kt`:
/// always 6 full Monday–Sunday weeks (42 days) so every month renders at the same height and
/// switching months never reflows the rest of the screen. No SwiftUI here, so it can be unit
/// tested on its own.
enum CalendarMonthGrid {

    static let rows = 6
    static let columns = 7

    /// The 42 dates to display for the month containing `month`, including the leading and
    /// trailing days of adjacent months needed to fill the first and last weeks. Every date is
    /// start-of-day.
    static func days(for month: Date, calendar: Calendar) -> [Date] {
        guard let gridStart = gridStart(for: month, calendar: calendar) else { return [] }
        return (0..<(rows * columns)).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }

    /// First day of the month `month` belongs to, at start-of-day.
    static func firstDay(of month: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: month)
        return calendar.date(from: components) ?? calendar.startOfDay(for: month)
    }

    static func month(_ month: Date, offsetBy months: Int, calendar: Calendar) -> Date {
        let first = firstDay(of: month, calendar: calendar)
        return calendar.date(byAdding: .month, value: months, to: first) ?? first
    }

    static func isSameMonth(_ date: Date, as month: Date, calendar: Calendar) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    /// The Monday on or before the 1st of the month. Weeks always start on Monday, matching
    /// Android and `HeatmapGrid`, rather than following the device locale — the two grids on
    /// the detail screen have to line up with each other.
    private static func gridStart(for month: Date, calendar: Calendar) -> Date? {
        let first = firstDay(of: month, calendar: calendar)
        let weekday = calendar.component(.weekday, from: first) // 1 = Sunday ... 7 = Saturday
        let daysSinceMonday = (weekday - 2 + 7) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: first)
    }
}
