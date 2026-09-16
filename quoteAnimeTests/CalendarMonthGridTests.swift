import Foundation
import Testing
@testable import quoteAnime

/// Pure geometry, mirroring Android's `CalendarMonthGridTest`: always 42 days, always starting
/// on a Monday, always covering the whole month.
@Suite("CalendarMonthGrid")
struct CalendarMonthGridTests {

    private let calendar = TestCalendar.fixed

    private func month(_ year: Int, _ month: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        components.hour = 12
        return TestCalendar.fixed.date(from: components)!
    }

    @Test(
        "siempre son 42 días, sin importar el mes",
        arguments: [(2026, 1), (2026, 2), (2026, 3), (2024, 2), (2026, 11), (2026, 12)]
    )
    func alwaysFortyTwoDays(year: Int, monthNumber: Int) {
        let days = CalendarMonthGrid.days(for: month(year, monthNumber), calendar: calendar)

        #expect(days.count == CalendarMonthGrid.rows * CalendarMonthGrid.columns)
        #expect(days.count == 42)
    }

    @Test(
        "la grilla siempre arranca en lunes",
        arguments: [(2026, 1), (2026, 2), (2026, 3), (2026, 6), (2026, 9), (2027, 2)]
    )
    func gridStartsOnMonday(year: Int, monthNumber: Int) {
        let days = CalendarMonthGrid.days(for: month(year, monthNumber), calendar: calendar)

        // `Calendar` weekday numbering: 2 = Monday.
        #expect(calendar.component(.weekday, from: days[0]) == 2)
    }

    @Test("los días son consecutivos y sin huecos")
    func daysAreConsecutive() {
        let days = CalendarMonthGrid.days(for: month(2026, 3), calendar: calendar)

        for index in 1..<days.count {
            let expected = calendar.date(byAdding: .day, value: 1, to: days[index - 1])!
            #expect(calendar.isDate(days[index], inSameDayAs: expected))
        }
    }

    @Test(
        "la grilla contiene el mes entero",
        arguments: [(2026, 1), (2026, 2), (2024, 2), (2026, 5), (2026, 8)]
    )
    func gridContainsTheWholeMonth(year: Int, monthNumber: Int) {
        let anchor = month(year, monthNumber)
        let days = CalendarMonthGrid.days(for: anchor, calendar: calendar)
        let inMonth = days.filter { CalendarMonthGrid.isSameMonth($0, as: anchor, calendar: calendar) }

        let expectedCount = calendar.range(of: .day, in: .month, for: anchor)!.count
        #expect(inMonth.count == expectedCount)
        #expect(calendar.component(.day, from: inMonth.first!) == 1)
        #expect(calendar.component(.day, from: inMonth.last!) == expectedCount)
    }

    @Test("un mes que arranca lunes no trae días del mes anterior")
    func monthStartingOnMondayHasNoLeadingDays() {
        // 2026-06-01 is a Monday.
        let june = month(2026, 6)
        let days = CalendarMonthGrid.days(for: june, calendar: calendar)

        #expect(calendar.component(.day, from: days[0]) == 1)
        #expect(CalendarMonthGrid.isSameMonth(days[0], as: june, calendar: calendar))
    }

    @Test("moverse de mes cruza bien el fin de año", arguments: [(-1, 2025, 12), (1, 2026, 2), (12, 2027, 1), (-13, 2024, 12)])
    func monthOffsetCrossesYears(offset: Int, expectedYear: Int, expectedMonth: Int) {
        let january = month(2026, 1)

        let moved = CalendarMonthGrid.month(january, offsetBy: offset, calendar: calendar)

        #expect(calendar.component(.year, from: moved) == expectedYear)
        #expect(calendar.component(.month, from: moved) == expectedMonth)
    }

    @Test("firstDay normaliza cualquier día del mes al primero a las 00:00")
    func firstDayNormalises() {
        let midMonth = TestCalendar.today // 2026-03-15 12:00

        let first = CalendarMonthGrid.firstDay(of: midMonth, calendar: calendar)

        #expect(calendar.component(.day, from: first) == 1)
        #expect(calendar.component(.month, from: first) == 3)
        #expect(first == calendar.startOfDay(for: first))
    }

    @Test("isSameMonth distingue el mismo mes de otro año")
    func sameMonthIsYearAware() {
        let march2026 = month(2026, 3)
        let march2025 = month(2025, 3)

        #expect(CalendarMonthGrid.isSameMonth(march2026, as: march2026, calendar: calendar))
        #expect(CalendarMonthGrid.isSameMonth(march2025, as: march2026, calendar: calendar) == false)
    }
}
