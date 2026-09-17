import Foundation
import Testing
@testable import quoteAnime

/// iOS counterpart of Android's `RoutineWidgetScheduler`. What matters is the same two things
/// Android's scheduler guarantees: every habit the widgets could be showing ends up in the
/// snapshot, and a failed read leaves the previous snapshot alone instead of blanking the widget.
@Suite("RoutineWidgetRefresher")
struct RoutineWidgetRefresherTests {

    private static let calendar = TestCalendar.fixed
    private static let today = TestCalendar.today

    private static func makeSUT(
        seed: [Habit] = [],
        archived: Set<String> = [],
        completions: [String: [Int]] = [:]
    ) -> (RoutineWidgetRefresher, Box) {
        let repository = FakeHabitRepository(calendar: calendar)
        repository.seed(habits: seed, archived: archived)
        for (habitId, offsets) in completions {
            repository.seedCompletions(habitId: habitId, dates: offsets.map { TestCalendar.day($0) })
        }
        let box = Box()
        let refresher = RoutineWidgetRefresher(
            getActiveHabits: GetActiveHabitsUseCase(repository: repository, calendar: calendar),
            getArchivedHabits: GetArchivedHabitsUseCase(repository: repository, calendar: calendar),
            getGlobalStreak: GetGlobalStreakUseCase(repository: repository, calendar: calendar),
            now: { today },
            publish: { box.published.append($0) }
        )
        return (refresher, box)
    }

    /// Collects what the refresher publishes instead of letting it reach the App Group.
    final class Box {
        var published: [HabitWidgetSnapshot] = []
        var last: HabitWidgetSnapshot? { published.last }
    }

    // MARK: - Happy path

    @Test("publica los hábitos activos con su racha")
    func publishesActiveHabits() async throws {
        let (refresher, box) = Self.makeSUT(
            seed: [
                HabitFixture.make(id: "meditar", title: "Meditar"),
                HabitFixture.make(id: "leer", title: "Leer"),
            ],
            completions: ["meditar": [0, -1, -2], "leer": [-5]]
        )

        await refresher.refresh()

        let snapshot = try #require(box.last)
        #expect(snapshot.habits.count == 2)
        #expect(snapshot.habits.first { $0.id == "meditar" }?.currentStreak == 3)
        #expect(snapshot.habits.first { $0.id == "meditar" }?.completedToday == true)
        #expect(snapshot.habits.first { $0.id == "leer" }?.currentStreak == 0)
    }

    @Test("la racha global acompaña al snapshot")
    func publishesGlobalStreak() async throws {
        let (refresher, box) = Self.makeSUT(
            seed: [HabitFixture.make(id: "a"), HabitFixture.make(id: "b")],
            completions: ["a": [0, -2], "b": [-1]]
        )

        await refresher.refresh()

        // Any habit completed on a day keeps the global streak alive: today, ayer y anteayer.
        #expect(try #require(box.last).globalStreak == 3)
    }

    /// The reason archived habits are published at all: a widget bound to one must keep drawing
    /// its history rather than claim the habit is gone.
    @Test("los archivados también viajan, marcados")
    func publishesArchivedHabitsToo() async throws {
        let (refresher, box) = Self.makeSUT(
            seed: [HabitFixture.make(id: "activo"), HabitFixture.make(id: "guardado")],
            archived: ["guardado"],
            completions: ["activo": [0], "guardado": [-3]]
        )

        await refresher.refresh()

        let snapshot = try #require(box.last)
        #expect(snapshot.habits.count == 2)
        #expect(snapshot.habits.first { $0.id == "guardado" }?.archived == true)
        #expect(snapshot.habits.first { $0.id == "guardado" }?.completionDays.isEmpty == false)
    }

    // MARK: - Boundaries

    @Test("sin hábitos publica un snapshot vacío, no nada")
    func publishesEmptySnapshot() async throws {
        let (refresher, box) = Self.makeSUT()

        await refresher.refresh()

        let snapshot = try #require(box.last)
        #expect(snapshot.habits.isEmpty)
        #expect(snapshot.globalStreak == 0)
    }

    @Test("un hábito borrado deja de aparecer en el siguiente snapshot")
    func deletedHabitDisappears() async throws {
        let repository = FakeHabitRepository(calendar: Self.calendar)
        repository.seed(habits: [HabitFixture.make(id: "meditar"), HabitFixture.make(id: "leer")])
        let box = Box()
        let refresher = RoutineWidgetRefresher(
            getActiveHabits: GetActiveHabitsUseCase(repository: repository, calendar: Self.calendar),
            getArchivedHabits: GetArchivedHabitsUseCase(repository: repository, calendar: Self.calendar),
            getGlobalStreak: GetGlobalStreakUseCase(repository: repository, calendar: Self.calendar),
            now: { Self.today },
            publish: { box.published.append($0) }
        )

        await refresher.refresh()
        #expect(try #require(box.last).habits.count == 2)

        try await repository.deleteHabit(id: "leer")
        await refresher.refresh()

        let snapshot = try #require(box.last)
        #expect(snapshot.habits.map(\.id) == ["meditar"])
    }

    // MARK: - Error branch

    @Test("si el repositorio falla no se publica nada y queda el snapshot anterior")
    func repositoryFailureKeepsThePreviousSnapshot() async {
        let repository = FailingHabitRepository()
        let box = Box()
        let refresher = RoutineWidgetRefresher(
            getActiveHabits: GetActiveHabitsUseCase(repository: repository, calendar: Self.calendar),
            getArchivedHabits: GetArchivedHabitsUseCase(repository: repository, calendar: Self.calendar),
            getGlobalStreak: GetGlobalStreakUseCase(repository: repository, calendar: Self.calendar),
            now: { Self.today },
            publish: { box.published.append($0) }
        )

        await refresher.refresh()

        #expect(box.published.isEmpty)
    }
}

/// Every read throws — stands in for a SwiftData store that failed to open.
private struct FailingHabitRepositoryError: Error {}

private struct FailingHabitRepository: HabitRepository {
    func fetchActiveHabits() async throws -> [Habit] { throw FailingHabitRepositoryError() }
    func fetchArchivedHabits() async throws -> [Habit] { throw FailingHabitRepositoryError() }
    func fetchCompletions(habitId: String) async throws -> [Date] { throw FailingHabitRepositoryError() }
    func fetchAllCompletionDates() async throws -> [Date] { throw FailingHabitRepositoryError() }
    func countActiveHabits() async throws -> Int { throw FailingHabitRepositoryError() }
    func fetchHabit(id: String) async throws -> Habit? { throw FailingHabitRepositoryError() }
    func saveHabit(_ habit: Habit) async throws { throw FailingHabitRepositoryError() }
    func setCompletion(habitId: String, date: Date, completed: Bool) async throws { throw FailingHabitRepositoryError() }
    func isCompleted(habitId: String, date: Date) async throws -> Bool { throw FailingHabitRepositoryError() }
    func archiveHabit(id: String) async throws { throw FailingHabitRepositoryError() }
    func unarchiveHabit(id: String) async throws { throw FailingHabitRepositoryError() }
    func deleteHabit(id: String) async throws { throw FailingHabitRepositoryError() }
}
