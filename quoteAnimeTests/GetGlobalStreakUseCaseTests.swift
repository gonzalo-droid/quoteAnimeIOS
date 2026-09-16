import Foundation
import Testing
@testable import quoteAnime

/// The global streak counts a day as done when *any* habit was completed that day — the
/// same rule as Android's `GetGlobalStreakUseCase`, which maps over
/// `repository.getAllCompletionDates()`.
///
/// Note: iOS's use case reads `Date()` internally instead of taking `today` as a parameter
/// (Android takes `today: LocalDate`), so these fixtures are built relative to the real
/// current date rather than `TestCalendar.today`.
@Suite("GetGlobalStreakUseCase")
struct GetGlobalStreakUseCaseTests {

    private func daysAgo(_ count: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -count, to: Date())!
    }

    @Test("sin ningún hábito completado la racha global es cero")
    func noCompletions() async throws {
        let repository = FakeHabitRepository()

        let state = try await GetGlobalStreakUseCase(repository: repository).execute()

        #expect(state.current == 0)
        #expect(state.best == 0)
        #expect(state.completedToday == false)
    }

    @Test("dos hábitos distintos en días consecutivos forman una sola racha")
    func differentHabitsChainTheStreak() async throws {
        let repository = FakeHabitRepository()
        repository.seedCompletions(habitId: "meditar", dates: [daysAgo(0)])
        repository.seedCompletions(habitId: "leer", dates: [daysAgo(1)])
        repository.seedCompletions(habitId: "entrenar", dates: [daysAgo(2)])

        let state = try await GetGlobalStreakUseCase(repository: repository).execute()

        #expect(state.current == 3)
        #expect(state.best == 3)
        #expect(state.completedToday == true)
    }

    @Test("varios hábitos el mismo día cuentan como un solo día")
    func sameDayMultipleHabitsCountOnce() async throws {
        let repository = FakeHabitRepository()
        repository.seedCompletions(habitId: "meditar", dates: [daysAgo(0)])
        repository.seedCompletions(habitId: "leer", dates: [daysAgo(0)])
        repository.seedCompletions(habitId: "entrenar", dates: [daysAgo(0)])

        let state = try await GetGlobalStreakUseCase(repository: repository).execute()

        #expect(state.current == 1)
        #expect(state.best == 1)
    }

    @Test("un día sin ningún hábito corta la racha global")
    func gapBreaksStreak() async throws {
        let repository = FakeHabitRepository()
        repository.seedCompletions(habitId: "meditar", dates: [daysAgo(0)])
        // nothing on daysAgo(1)
        repository.seedCompletions(habitId: "leer", dates: [daysAgo(2), daysAgo(3), daysAgo(4)])

        let state = try await GetGlobalStreakUseCase(repository: repository).execute()

        #expect(state.current == 1)
        #expect(state.best == 3)
        #expect(state.completedToday == true)
    }

    @Test("la racha global sigue viva si el último día fue ayer")
    func aliveWhenLastWasYesterday() async throws {
        let repository = FakeHabitRepository()
        repository.seedCompletions(habitId: "meditar", dates: [daysAgo(1), daysAgo(2)])

        let state = try await GetGlobalStreakUseCase(repository: repository).execute()

        #expect(state.current == 2)
        #expect(state.completedToday == false)
    }

    @Test("hábitos archivados siguen aportando a la racha global")
    func archivedHabitsStillCount() async throws {
        // `fetchAllCompletionDates` is not filtered by archive state on either platform:
        // archiving a habit must not retroactively rewrite the user's history.
        let repository = FakeHabitRepository()
        let archived = HabitFixture.make(id: "viejo")
        repository.seed(habits: [archived], archived: ["viejo"])
        repository.seedCompletions(habitId: "viejo", dates: [daysAgo(0), daysAgo(1)])

        let state = try await GetGlobalStreakUseCase(repository: repository).execute()

        #expect(state.current == 2)
    }
}
