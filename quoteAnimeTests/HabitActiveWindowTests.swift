import Foundation
import Testing
@testable import quoteAnime

/// `Habit.isActiveOn` is the single definition of "this day belongs to this habit", used by
/// the toggle guard, the heatmap and the month calendar. Mirrors Android's
/// `!date.isBefore(startDate) && (endDate == null || !date.isAfter(endDate))`.
@Suite("Habit.isActiveOn")
struct HabitActiveWindowTests {

    private let calendar = TestCalendar.fixed

    /// One row of the boundary table. Offsets are relative to `TestCalendar.today`.
    struct WindowCase: CustomTestStringConvertible {
        let label: String
        let startOffset: Int
        let endOffset: Int?
        let dayOffset: Int
        let expected: Bool

        var testDescription: String { label }
    }

    @Test(
        "los bordes exactos de la ventana activa",
        arguments: [
            WindowCase(label: "primer día", startOffset: -10, endOffset: -2, dayOffset: -10, expected: true),
            WindowCase(label: "un día antes del primero", startOffset: -10, endOffset: -2, dayOffset: -11, expected: false),
            WindowCase(label: "último día", startOffset: -10, endOffset: -2, dayOffset: -2, expected: true),
            WindowCase(label: "un día después del último", startOffset: -10, endOffset: -2, dayOffset: -1, expected: false),
            WindowCase(label: "día del medio", startOffset: -10, endOffset: -2, dayOffset: -6, expected: true),
            WindowCase(label: "sin endDate, hoy", startOffset: -10, endOffset: nil, dayOffset: 0, expected: true),
            WindowCase(label: "sin endDate, muy en el futuro", startOffset: -10, endOffset: nil, dayOffset: 3650, expected: true),
            WindowCase(label: "sin endDate, antes del inicio", startOffset: -10, endOffset: nil, dayOffset: -11, expected: false),
            WindowCase(label: "ventana de un solo día, ese día", startOffset: -5, endOffset: -5, dayOffset: -5, expected: true),
            WindowCase(label: "ventana de un solo día, el anterior", startOffset: -5, endOffset: -5, dayOffset: -6, expected: false),
            WindowCase(label: "ventana de un solo día, el siguiente", startOffset: -5, endOffset: -5, dayOffset: -4, expected: false)
        ]
    )
    func boundaries(scenario: WindowCase) {
        let habit = HabitFixture.make(
            startDate: TestCalendar.day(scenario.startOffset),
            endDate: scenario.endOffset.map { TestCalendar.day($0) }
        )

        #expect(habit.isActiveOn(TestCalendar.day(scenario.dayOffset), calendar: calendar) == scenario.expected)
    }

    @Test(
        "la hora del día no cambia el resultado",
        arguments: [(0, 0), (9, 30), (23, 59)]
    )
    func timeOfDayIsIrrelevant(hour: Int, minute: Int) {
        // The habit starts "today at noon"; a tap stamped at 00:00 the same day must still be
        // inside the window. Android never hits this because `LocalDate` carries no time.
        let habit = HabitFixture.make(startDate: TestCalendar.day(0, hour: 12), endDate: nil)

        #expect(habit.isActiveOn(TestCalendar.day(0, hour: hour, minute: minute), calendar: calendar))
    }

    @Test("una ventana invertida no acepta ningún día")
    func invertedWindowAcceptsNothing() {
        // The use cases reject this at creation time, but the model must not pretend such a
        // habit is active either.
        let habit = HabitFixture.make(startDate: TestCalendar.day(-2), endDate: TestCalendar.day(-10))

        for offset in -12...0 {
            #expect(habit.isActiveOn(TestCalendar.day(offset), calendar: calendar) == false)
        }
    }
}
