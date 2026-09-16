import Foundation
import Testing
@testable import quoteAnime

/// Marking a day is a toggle keyed by calendar day, never by instant.
@Suite("ToggleHabitCompletionUseCase")
struct ToggleHabitCompletionUseCaseTests {

    private func makeSUT() -> (ToggleHabitCompletionUseCase, FakeHabitRepository) {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: [HabitFixture.make(id: "meditar")])
        return (ToggleHabitCompletionUseCase(repository: repository), repository)
    }

    @Test("marcar un día que no estaba marcado lo completa")
    func togglingMarksTheDay() async throws {
        let (useCase, repository) = makeSUT()

        try await useCase.execute(habitId: "meditar", date: TestCalendar.today)

        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.today))
        #expect(repository.completionCount(habitId: "meditar") == 1)
    }

    @Test("marcar dos veces el mismo día lo desmarca")
    func togglingTwiceUnmarks() async throws {
        let (useCase, repository) = makeSUT()

        try await useCase.execute(habitId: "meditar", date: TestCalendar.today)
        try await useCase.execute(habitId: "meditar", date: TestCalendar.today)

        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.today) == false)
        #expect(repository.completionCount(habitId: "meditar") == 0)
    }

    @Test("el toggle alterna de forma estable", arguments: 1...6)
    func togglingNTimesAlternates(times: Int) async throws {
        let (useCase, repository) = makeSUT()

        for _ in 0..<times {
            try await useCase.execute(habitId: "meditar", date: TestCalendar.today)
        }

        let expectedCompleted = times % 2 == 1
        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.today) == expectedCompleted)
        #expect(repository.completionCount(habitId: "meditar") == (expectedCompleted ? 1 : 0))
    }

    @Test(
        "cualquier hora del día toca la misma entrada",
        arguments: [(0, 1), (9, 30), (23, 59)]
    )
    func anyTimeOfDayHitsTheSameEntry(hour: Int, minute: Int) async throws {
        let (useCase, repository) = makeSUT()

        // Mark at noon, then toggle at a different time on the same day.
        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(0, hour: 12))
        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(0, hour: hour, minute: minute))

        #expect(repository.completionCount(habitId: "meditar") == 0, "debe haber desmarcado el mismo día, no creado otro")
    }

    @Test("días distintos son entradas independientes")
    func differentDaysAreIndependent() async throws {
        let (useCase, repository) = makeSUT()

        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(0))
        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(-1))
        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(-2))

        #expect(repository.completionCount(habitId: "meditar") == 3)

        // Unmarking yesterday leaves the other two alone.
        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(-1))

        #expect(repository.completionCount(habitId: "meditar") == 2)
        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.day(0)))
        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.day(-1)) == false)
        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.day(-2)))
    }

    @Test("el toggle de un hábito no afecta a otro")
    func habitsAreIsolated() async throws {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: [HabitFixture.make(id: "meditar"), HabitFixture.make(id: "leer")])
        let useCase = ToggleHabitCompletionUseCase(repository: repository)

        try await useCase.execute(habitId: "meditar", date: TestCalendar.today)

        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.today))
        #expect(try await repository.isCompleted(habitId: "leer", date: TestCalendar.today) == false)
    }

    // MARK: - Divergences with Android, pinned deliberately
    //
    // Android's ToggleHabitCompletionUseCase returns HabitNotFound / FutureDate /
    // OutsideHabitRange before touching the repository. iOS has none of those guards.
    // These two tests document what iOS does *today* so the gap is visible in the suite
    // rather than only in a report. When the guards are ported, they should fail and be
    // rewritten to assert the rejection.

    @Test("DIVERGENCIA: iOS acepta marcar un día futuro (Android lo rechaza con FutureDate)")
    func futureDatesAreCurrentlyAccepted() async throws {
        let (useCase, repository) = makeSUT()

        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(+5))

        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.day(+5)))
    }

    @Test("DIVERGENCIA: iOS acepta un habitId inexistente (Android lo rechaza con HabitNotFound)")
    func unknownHabitIsCurrentlyAccepted() async throws {
        let (useCase, repository) = makeSUT()

        try await useCase.execute(habitId: "no-existe", date: TestCalendar.today)

        #expect(repository.completionCount(habitId: "no-existe") == 1)
    }
}
