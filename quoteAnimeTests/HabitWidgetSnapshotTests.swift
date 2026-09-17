import Foundation
import Testing
@testable import quoteAnime

/// The snapshot is the *only* thing the widget extension can see: it has no access to SwiftData,
/// so anything missing or malformed here is a blank widget on the user's home screen with no way
/// to debug it from inside the app. Two properties matter most:
///
/// - **Round trip**: what the app writes is exactly what the extension reads back.
/// - **Forward compatibility**: a snapshot written by an older build (before the per-habit widget
///   added completions, the archived flag and the glyph) must still decode, or updating the app
///   would blank the summary widget until the user next opens "Mi Rutina".
@Suite("Snapshot del widget de hábitos")
struct HabitWidgetSnapshotTests {

    private static let calendar = TestCalendar.fixed
    private static let today = TestCalendar.today

    private static func progress(
        habit: Habit,
        dayOffsets: [Int],
        streak: StreakState = StreakState()
    ) -> HabitWithProgress {
        HabitWithProgress(
            habit: habit,
            completions: Set(dayOffsets.map { TestCalendar.day($0) }),
            streak: streak
        )
    }

    private static func encodeDecode(_ snapshot: HabitWidgetSnapshot) throws -> HabitWidgetSnapshot {
        let data = try JSONEncoder().encode(snapshot)
        return try JSONDecoder().decode(HabitWidgetSnapshot.self, from: data)
    }

    // MARK: - Round trip

    @Test("lo que se escribe es lo que se lee")
    func roundTrip() throws {
        let habit = HabitFixture.make(id: "meditar", title: "Meditar", iconKey: "book", colorIndex: 3)
        let snapshot = HabitWidgetDataWriter.snapshot(
            active: [Self.progress(
                habit: habit,
                dayOffsets: [0, -1, -2],
                streak: StreakState(current: 3, best: 7, lastCompletedDate: Self.today, completedToday: true)
            )],
            globalStreak: 3,
            today: Self.today,
            calendar: Self.calendar
        )

        let decoded = try Self.encodeDecode(snapshot)
        let item = try #require(decoded.habits.first)

        #expect(decoded.habits.count == 1)
        #expect(decoded.globalStreak == 3)
        #expect(item.id == "meditar")
        #expect(item.title == "Meditar")
        #expect(item.colorIndex == 3)
        #expect(item.currentStreak == 3)
        #expect(item.completedToday)
        #expect(item.archived == false)
        #expect(item.symbolName == HabitIcons.symbol(for: "book"))
        #expect(item.completionDays.count == 3)
    }

    @Test("un snapshot vacío sigue siendo un snapshot válido")
    func emptySnapshotRoundTrips() throws {
        let snapshot = HabitWidgetDataWriter.snapshot(active: [], globalStreak: 0, today: Self.today, calendar: Self.calendar)
        let decoded = try Self.encodeDecode(snapshot)

        #expect(decoded.habits.isEmpty)
        #expect(decoded.globalStreak == 0)
    }

    // MARK: - Days travel as text

    @Test(
        "cada día se guarda como yyyy-MM-dd",
        arguments: [
            (0, "2026-03-15"),
            (-1, "2026-03-14"),
            (-15, "2026-02-28"),
            (-74, "2025-12-31"),
        ]
    )
    func dayKeyFormat(offset: Int, expected: String) {
        #expect(HabitWidgetDay.key(TestCalendar.day(offset), calendar: Self.calendar) == expected)
    }

    @Test("la hora del día no cambia la clave")
    func dayKeyIgnoresTimeOfDay() {
        let earlyMorning = TestCalendar.day(0, hour: 0, minute: 5)
        let lateNight = TestCalendar.day(0, hour: 23, minute: 55)

        #expect(HabitWidgetDay.key(earlyMorning, calendar: Self.calendar) == "2026-03-15")
        #expect(HabitWidgetDay.key(lateNight, calendar: Self.calendar) == "2026-03-15")
    }

    // MARK: - The 9-week window

    /// The heatmap only ever draws 9 weeks, so shipping a habit's whole history would grow the
    /// snapshot without changing a single pixel. Android trims the same way in
    /// `UpdateHabitWidgetWorker` (`today.minusWeeks(9)`).
    @Test("sólo viajan los días de las últimas 9 semanas")
    func trimsToTheHeatmapWindow() {
        let habit = HabitFixture.make(id: "correr", startDate: TestCalendar.day(-400))
        let snapshot = HabitWidgetDataWriter.snapshot(
            active: [Self.progress(habit: habit, dayOffsets: [0, -10, -62, -63, -64, -200])],
            globalStreak: 1,
            today: Self.today,
            calendar: Self.calendar
        )
        let days = snapshot.habits[0].completionDays

        // 9 weeks back from 2026-03-15 is 2026-01-11, i.e. offset -63 — the boundary is included.
        #expect(days.contains(HabitWidgetDay.key(TestCalendar.day(0), calendar: Self.calendar)))
        #expect(days.contains(HabitWidgetDay.key(TestCalendar.day(-10), calendar: Self.calendar)))
        #expect(days.contains(HabitWidgetDay.key(TestCalendar.day(-62), calendar: Self.calendar)))
        #expect(days.contains(HabitWidgetDay.key(TestCalendar.day(-63), calendar: Self.calendar)))
        #expect(!days.contains(HabitWidgetDay.key(TestCalendar.day(-64), calendar: Self.calendar)))
        #expect(!days.contains(HabitWidgetDay.key(TestCalendar.day(-200), calendar: Self.calendar)))
    }

    /// Whatever the window trims must still cover every cell the grid will draw, otherwise the
    /// oldest column would render empty even for a habit completed every single day.
    @Test("la ventana recortada cubre toda la grilla que se va a dibujar")
    func windowCoversTheWholeGrid() {
        let habit = HabitFixture.make(id: "leer", startDate: TestCalendar.day(-400))
        let everyDay = Array(-90...0)
        let snapshot = HabitWidgetDataWriter.snapshot(
            active: [Self.progress(habit: habit, dayOffsets: everyDay)],
            globalStreak: 1,
            today: Self.today,
            calendar: Self.calendar
        )
        let days = snapshot.habits[0].completionDays

        let gridStart = HeatmapGrid.gridStart(
            today: Self.calendar.startOfDay(for: Self.today),
            weeks: HabitWidgetSnapshot.heatmapWeeks
        )
        let todayStart = Self.calendar.startOfDay(for: Self.today)

        var missing: [String] = []
        for column in 0..<HabitWidgetSnapshot.heatmapWeeks {
            for row in 0..<HeatmapGrid.rows {
                let date = HeatmapGrid.date(column: column, row: row, gridStart: gridStart)
                guard date <= todayStart else { continue }
                let key = HabitWidgetDay.key(date, calendar: Self.calendar)
                if !days.contains(key) { missing.append(key) }
            }
        }
        #expect(missing.isEmpty, "Días de la grilla que el snapshot no trae: \(missing.sorted())")
    }

    @Test("un hábito sin días marcados viaja con la lista vacía, no ausente")
    func noCompletions() throws {
        let snapshot = HabitWidgetDataWriter.snapshot(
            active: [Self.progress(habit: HabitFixture.make(id: "nuevo"), dayOffsets: [])],
            globalStreak: 0,
            today: Self.today,
            calendar: Self.calendar
        )
        let decoded = try Self.encodeDecode(snapshot)

        #expect(decoded.habits[0].completions == [])
        #expect(decoded.habits[0].completionDays.isEmpty)
    }

    // MARK: - Archived habits

    /// A widget bound to a habit the user later archives must keep showing its history, the way
    /// Android's worker does (it looks the habit up by id, which returns archived habits too).
    /// The summary widget filters them out on its side.
    @Test("los hábitos archivados viajan marcados como tales")
    func archivedHabitsAreFlagged() throws {
        let snapshot = HabitWidgetDataWriter.snapshot(
            active: [Self.progress(habit: HabitFixture.make(id: "activo"), dayOffsets: [0])],
            archived: [Self.progress(habit: HabitFixture.make(id: "guardado", isArchived: true), dayOffsets: [-5])],
            globalStreak: 1,
            today: Self.today,
            calendar: Self.calendar
        )
        let decoded = try Self.encodeDecode(snapshot)

        #expect(decoded.habits.count == 2)
        #expect(decoded.habits.first { $0.id == "activo" }?.archived == false)
        #expect(decoded.habits.first { $0.id == "guardado" }?.archived == true)
    }

    // MARK: - Forward compatibility

    /// The exact JSON an app build before the per-habit widget wrote. Kept as a literal on
    /// purpose: it can't drift with the struct the way a re-encoded fixture would.
    private static let version1JSON = """
    {
      "globalStreak": 4,
      "habits": [
        { "id": "meditar", "title": "Meditar", "colorIndex": 0, "currentStreak": 4, "completedToday": true },
        { "id": "leer", "title": "Leer", "colorIndex": 2, "currentStreak": 0, "completedToday": false }
      ]
    }
    """

    @Test("un snapshot viejo, sin los campos nuevos, se sigue leyendo")
    func legacySnapshotStillDecodes() throws {
        let data = Data(Self.version1JSON.utf8)
        let decoded = try JSONDecoder().decode(HabitWidgetSnapshot.self, from: data)

        #expect(decoded.globalStreak == 4)
        #expect(decoded.habits.count == 2)

        let meditar = try #require(decoded.habits.first { $0.id == "meditar" })
        #expect(meditar.title == "Meditar")
        #expect(meditar.currentStreak == 4)
        #expect(meditar.completedToday)
        // The fields the old build knew nothing about degrade instead of failing to decode.
        #expect(meditar.archived == false)
        #expect(meditar.completionDays.isEmpty)
        #expect(meditar.symbolName == nil)
    }

    /// The summary widget's own read path over a legacy snapshot: nothing archived, everything
    /// listed. Pinned here because that widget shipped first and must not regress.
    @Test("el widget de resumen sigue viendo todos los hábitos de un snapshot viejo")
    func legacySnapshotKeepsTheSummaryWidgetWorking() throws {
        let decoded = try JSONDecoder().decode(HabitWidgetSnapshot.self, from: Data(Self.version1JSON.utf8))

        #expect(decoded.habits.filter { !$0.archived }.count == 2)
    }

    @Test("un JSON corrupto no se decodifica en vez de decodificarse a medias")
    func brokenJSONFailsLoudly() {
        let broken = Data(#"{"habits": [{"id": "x"}], "globalStreak": 1}"#.utf8)

        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(HabitWidgetSnapshot.self, from: broken)
        }
    }

    // MARK: - Icons

    /// The glyph is resolved on the app side so the extension doesn't need a copy of the icon
    /// table — including the legacy-key aliases, which the extension would have no way to know
    /// about.
    @Test("el ícono viaja ya resuelto a SF Symbol, alias incluidos", arguments: [
        "book", "dumbbell", "sports_soccer", "una_clave_que_no_existe",
    ])
    func symbolIsResolvedBeforeTravelling(iconKey: String) {
        let snapshot = HabitWidgetDataWriter.snapshot(
            active: [Self.progress(habit: HabitFixture.make(iconKey: iconKey), dayOffsets: [])],
            globalStreak: 0,
            today: Self.today,
            calendar: Self.calendar
        )

        #expect(snapshot.habits[0].symbolName == HabitIcons.symbol(for: iconKey))
    }
}
