import Foundation
import Testing
@testable import quoteAnime

/// The global streak counts a day as done when *any* habit was completed that day — the
/// same rule as Android's `GetGlobalStreakUseCase`, which maps over
/// `repository.getAllCompletionDates()`.
///
/// `today` is injected (Android takes `today: LocalDate`), so every fixture below is pinned to
/// `TestCalendar.today` instead of the real clock.
@Suite("GetGlobalStreakUseCase")
struct GetGlobalStreakUseCaseTests {

    private func makeSUT() -> (GetGlobalStreakUseCase, FakeHabitRepository) {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        return (GetGlobalStreakUseCase(repository: repository, calendar: TestCalendar.fixed), repository)
    }

    @Test("sin ningún hábito completado la racha global es cero")
    func noCompletions() async throws {
        let (useCase, _) = makeSUT()

        let state = try await useCase.execute(today: TestCalendar.today)

        #expect(state.current == 0)
        #expect(state.best == 0)
        #expect(state.completedToday == false)
    }

    @Test("dos hábitos distintos en días consecutivos forman una sola racha")
    func differentHabitsChainTheStreak() async throws {
        let (useCase, repository) = makeSUT()
        repository.seedCompletions(habitId: "meditar", dates: [TestCalendar.day(0)])
        repository.seedCompletions(habitId: "leer", dates: [TestCalendar.day(-1)])
        repository.seedCompletions(habitId: "entrenar", dates: [TestCalendar.day(-2)])

        let state = try await useCase.execute(today: TestCalendar.today)

        #expect(state.current == 3)
        #expect(state.best == 3)
        #expect(state.completedToday == true)
    }

    @Test("varios hábitos el mismo día cuentan como un solo día")
    func sameDayMultipleHabitsCountOnce() async throws {
        let (useCase, repository) = makeSUT()
        repository.seedCompletions(habitId: "meditar", dates: [TestCalendar.day(0)])
        repository.seedCompletions(habitId: "leer", dates: [TestCalendar.day(0)])
        repository.seedCompletions(habitId: "entrenar", dates: [TestCalendar.day(0)])

        let state = try await useCase.execute(today: TestCalendar.today)

        #expect(state.current == 1)
        #expect(state.best == 1)
    }

    @Test("un día sin ningún hábito corta la racha global")
    func gapBreaksStreak() async throws {
        let (useCase, repository) = makeSUT()
        repository.seedCompletions(habitId: "meditar", dates: [TestCalendar.day(0)])
        // nothing on day(-1)
        repository.seedCompletions(habitId: "leer", dates: [TestCalendar.day(-2), TestCalendar.day(-3), TestCalendar.day(-4)])

        let state = try await useCase.execute(today: TestCalendar.today)

        #expect(state.current == 1)
        #expect(state.best == 3)
        #expect(state.completedToday == true)
    }

    @Test("la racha global sigue viva si el último día fue ayer")
    func aliveWhenLastWasYesterday() async throws {
        let (useCase, repository) = makeSUT()
        repository.seedCompletions(habitId: "meditar", dates: [TestCalendar.day(-1), TestCalendar.day(-2)])

        let state = try await useCase.execute(today: TestCalendar.today)

        #expect(state.current == 2)
        #expect(state.completedToday == false)
    }

    @Test("hábitos archivados siguen aportando a la racha global")
    func archivedHabitsStillCount() async throws {
        // `fetchAllCompletionDates` is not filtered by archive state on either platform:
        // archiving a habit must not retroactively rewrite the user's history.
        let (useCase, repository) = makeSUT()
        repository.seed(habits: [HabitFixture.make(id: "viejo")], archived: ["viejo"])
        repository.seedCompletions(habitId: "viejo", dates: [TestCalendar.day(0), TestCalendar.day(-1)])

        let state = try await useCase.execute(today: TestCalendar.today)

        #expect(state.current == 2)
    }

    // MARK: - `today` is honoured (the reason it became a parameter)

    @Test(
        "la misma historia da rachas distintas según qué día sea hoy",
        arguments: [
            (0, 3, true),   // hoy: racha viva de 3, completada hoy
            (1, 3, false),  // mañana: sigue viva (el último fue ayer), pero no completada hoy
            (2, 0, false),  // pasado mañana: ya se cortó
            (10, 0, false)
        ]
    )
    func streakDependsOnToday(todayOffset: Int, expectedCurrent: Int, expectedCompletedToday: Bool) async throws {
        let (useCase, repository) = makeSUT()
        repository.seedCompletions(
            habitId: "meditar",
            dates: [TestCalendar.day(0), TestCalendar.day(-1), TestCalendar.day(-2)]
        )

        let state = try await useCase.execute(today: TestCalendar.day(todayOffset))

        #expect(state.current == expectedCurrent)
        #expect(state.completedToday == expectedCompletedToday)
        #expect(state.best == 3, "la mejor racha no depende de hoy")
    }
}
