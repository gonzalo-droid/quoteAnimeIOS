import Foundation
import Testing
@testable import quoteAnime

/// The picker in the per-habit widget's edit sheet (`HabitOptionsProvider`) and the widget's own
/// lookup both live in the widget extension — a separate binary this test target cannot import.
/// What they actually *decide* is not in the extension though: both delegate to `activeHabits` and
/// `habit(id:)` on the snapshot, mirrored into the app target precisely so those three rules can be
/// pinned here.
///
/// The untestable remainder is the plumbing: reading the App Group and handing AppIntents the list.
/// That is exercised in the simulator instead.
@Suite("Selector de hábito del widget")
struct HabitWidgetEntityQueryTests {

    private static let calendar = TestCalendar.fixed
    private static let today = TestCalendar.today

    private static func snapshot(
        active: [Habit] = [],
        archived: [Habit] = []
    ) -> HabitWidgetSnapshot {
        func progress(_ habit: Habit) -> HabitWithProgress {
            HabitWithProgress(habit: habit, completions: [TestCalendar.day(0)], streak: StreakState(current: 1))
        }
        return HabitWidgetDataWriter.snapshot(
            active: active.map(progress),
            archived: archived.map(progress),
            globalStreak: 1,
            today: today,
            calendar: calendar
        )
    }

    // MARK: - The list the picker offers

    @Test("ofrece los hábitos activos, en el orden en que están")
    func listsActiveHabits() {
        let snapshot = Self.snapshot(active: [
            HabitFixture.make(id: "meditar", title: "Meditar"),
            HabitFixture.make(id: "leer", title: "Leer"),
            HabitFixture.make(id: "correr", title: "Correr"),
        ])

        #expect(snapshot.activeHabits.map(\.id) == ["meditar", "leer", "correr"])
        #expect(snapshot.activeHabits.map(\.title) == ["Meditar", "Leer", "Correr"])
    }

    /// Same rule as Android's configure screen, which lists `repository.getActiveHabits()`.
    @Test("no ofrece los archivados")
    func doesNotListArchivedHabits() {
        let snapshot = Self.snapshot(
            active: [HabitFixture.make(id: "meditar")],
            archived: [HabitFixture.make(id: "guardado", isArchived: true)]
        )

        #expect(snapshot.activeHabits.map(\.id) == ["meditar"])
    }

    @Test("sin hábitos la lista queda vacía, no rompe")
    func emptyList() {
        #expect(Self.snapshot().activeHabits.isEmpty)
    }

    // MARK: - Resolving the habit a widget is already bound to

    @Test("resuelve por id el hábito elegido")
    func resolvesById() throws {
        let snapshot = Self.snapshot(active: [
            HabitFixture.make(id: "meditar", title: "Meditar", iconKey: "book", colorIndex: 5),
            HabitFixture.make(id: "leer", title: "Leer"),
        ])

        let found = try #require(snapshot.habit(id: "meditar"))
        #expect(found.title == "Meditar")
        #expect(found.colorIndex == 5)
        #expect(found.symbolName == HabitIcons.symbol(for: "book"))
    }

    /// A widget bound to a habit the user later archives keeps rendering: the habit is no longer
    /// offered in the picker, but it still resolves. Android behaves the same way — its worker
    /// looks the habit up by id, which returns archived habits too.
    @Test("un hábito archivado sigue resolviendo aunque ya no se ofrezca")
    func resolvesArchivedHabit() throws {
        let snapshot = Self.snapshot(
            active: [HabitFixture.make(id: "meditar")],
            archived: [HabitFixture.make(id: "guardado", title: "Guardado", isArchived: true)]
        )

        let found = try #require(snapshot.habit(id: "guardado"))
        #expect(found.title == "Guardado")
        #expect(found.archived)
        #expect(!snapshot.activeHabits.contains { $0.id == "guardado" })
    }

    /// The deleted case: the widget must fall back to "this habit no longer exists" rather than
    /// keep a stale title on screen.
    @Test("un hábito inexistente no resuelve", arguments: ["borrado", "", "meditar "])
    func unknownIdResolvesToNothing(id: String) {
        let snapshot = Self.snapshot(active: [HabitFixture.make(id: "meditar")])

        #expect(snapshot.habit(id: id) == nil)
    }

    @Test("buscar en un snapshot vacío no resuelve")
    func unknownIdInEmptySnapshot() {
        #expect(Self.snapshot().habit(id: "meditar") == nil)
    }

    // MARK: - What the picker shows for each habit

    @Test("cada hábito llega al selector con su título, color e ícono")
    func entityCarriesEverythingThePickerShows() throws {
        let snapshot = Self.snapshot(active: [
            HabitFixture.make(id: "entrenar", title: "Entrenar", iconKey: "dumbbell", colorIndex: 10)
        ])

        let item = try #require(snapshot.activeHabits.first)
        #expect(item.id == "entrenar")
        #expect(item.title == "Entrenar")
        #expect(item.colorIndex == 10)
        #expect(item.symbolName == "dumbbell.fill")
    }
}
