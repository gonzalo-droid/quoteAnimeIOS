import Foundation
import Testing
@testable import quoteAnime

/// `GetActiveHabitsUseCase` and `GetArchivedHabitsUseCase` attach each habit's own streak. Like
/// `GetGlobalStreakUseCase`, `today` is injected so the streak is pinned to
/// `TestCalendar.today` rather than the real clock.
@Suite("GetActiveHabitsUseCase / GetArchivedHabitsUseCase")
struct GetHabitListsUseCaseTests {

    private func makeRepository() -> FakeHabitRepository {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(
            habits: [HabitFixture.make(id: "activo"), HabitFixture.make(id: "archivado")],
            archived: ["archivado"]
        )
        let history = [TestCalendar.day(0), TestCalendar.day(-1), TestCalendar.day(-2)]
        repository.seedCompletions(habitId: "activo", dates: history)
        repository.seedCompletions(habitId: "archivado", dates: history)
        return repository
    }

    @Test(
        "la racha de cada hábito activo depende del día que se pase como hoy",
        arguments: [
            (0, 3, true),
            (1, 3, false),   // yesterday was the last completion: still alive
            (2, 0, false),   // a full day missed: broken
            (30, 0, false)
        ]
    )
    func activeStreakFollowsToday(todayOffset: Int, expectedCurrent: Int, expectedCompletedToday: Bool) async throws {
        let useCase = GetActiveHabitsUseCase(repository: makeRepository(), calendar: TestCalendar.fixed)

        let result = try await useCase.execute(today: TestCalendar.day(todayOffset))

        #expect(result.map(\.habit.id) == ["activo"])
        #expect(result[0].streak.current == expectedCurrent)
        #expect(result[0].streak.completedToday == expectedCompletedToday)
        #expect(result[0].streak.best == 3)
        #expect(result[0].completions.count == 3)
    }

    @Test(
        "la racha de cada hábito archivado también depende del día que se pase como hoy",
        arguments: [(0, 3), (1, 3), (2, 0)]
    )
    func archivedStreakFollowsToday(todayOffset: Int, expectedCurrent: Int) async throws {
        let useCase = GetArchivedHabitsUseCase(repository: makeRepository(), calendar: TestCalendar.fixed)

        let result = try await useCase.execute(today: TestCalendar.day(todayOffset))

        #expect(result.map(\.habit.id) == ["archivado"])
        #expect(result[0].streak.current == expectedCurrent)
    }

    @Test("sin hábitos ambas listas vuelven vacías")
    func emptyRepository() async throws {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)

        let active = try await GetActiveHabitsUseCase(repository: repository, calendar: TestCalendar.fixed)
            .execute(today: TestCalendar.today)
        let archived = try await GetArchivedHabitsUseCase(repository: repository, calendar: TestCalendar.fixed)
            .execute(today: TestCalendar.today)

        #expect(active.isEmpty)
        #expect(archived.isEmpty)
    }
}
