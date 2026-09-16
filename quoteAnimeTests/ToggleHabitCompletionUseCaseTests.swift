import Foundation
import Testing
@testable import quoteAnime

/// Marking a day is a toggle keyed by calendar day, never by instant — and it is guarded the
/// same way Android guards it: the habit must exist, the day must not be in the future, and it
/// must fall inside the habit's own start/end window.
@Suite("ToggleHabitCompletionUseCase")
struct ToggleHabitCompletionUseCaseTests {

    private func makeSUT(habit: Habit = HabitFixture.make(id: "meditar"))
        -> (ToggleHabitCompletionUseCase, FakeHabitRepository) {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: [habit])
        let useCase = ToggleHabitCompletionUseCase(repository: repository, calendar: TestCalendar.fixed)
        return (useCase, repository)
    }

    // MARK: - Toggling

    @Test("marcar un día que no estaba marcado lo completa")
    func togglingMarksTheDay() async throws {
        let (useCase, repository) = makeSUT()

        let completed = try await useCase.execute(
            habitId: "meditar", date: TestCalendar.today, today: TestCalendar.today
        )

        #expect(completed)
        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.today))
        #expect(repository.completionCount(habitId: "meditar") == 1)
    }

    @Test("marcar dos veces el mismo día lo desmarca")
    func togglingTwiceUnmarks() async throws {
        let (useCase, repository) = makeSUT()

        try await useCase.execute(habitId: "meditar", date: TestCalendar.today, today: TestCalendar.today)
        let completed = try await useCase.execute(
            habitId: "meditar", date: TestCalendar.today, today: TestCalendar.today
        )

        #expect(completed == false)
        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.today) == false)
        #expect(repository.completionCount(habitId: "meditar") == 0)
    }

    @Test("el toggle alterna de forma estable", arguments: 1...6)
    func togglingNTimesAlternates(times: Int) async throws {
        let (useCase, repository) = makeSUT()

        for _ in 0..<times {
            try await useCase.execute(habitId: "meditar", date: TestCalendar.today, today: TestCalendar.today)
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
        try await useCase.execute(
            habitId: "meditar", date: TestCalendar.day(0, hour: 12), today: TestCalendar.today
        )
        try await useCase.execute(
            habitId: "meditar", date: TestCalendar.day(0, hour: hour, minute: minute), today: TestCalendar.today
        )

        #expect(repository.completionCount(habitId: "meditar") == 0, "debe haber desmarcado el mismo día, no creado otro")
    }

    @Test("días distintos son entradas independientes")
    func differentDaysAreIndependent() async throws {
        let (useCase, repository) = makeSUT()

        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(0), today: TestCalendar.today)
        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(-1), today: TestCalendar.today)
        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(-2), today: TestCalendar.today)

        #expect(repository.completionCount(habitId: "meditar") == 3)

        // Unmarking yesterday leaves the other two alone.
        try await useCase.execute(habitId: "meditar", date: TestCalendar.day(-1), today: TestCalendar.today)

        #expect(repository.completionCount(habitId: "meditar") == 2)
        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.day(0)))
        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.day(-1)) == false)
        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.day(-2)))
    }

    @Test("el toggle de un hábito no afecta a otro")
    func habitsAreIsolated() async throws {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: [HabitFixture.make(id: "meditar"), HabitFixture.make(id: "leer")])
        let useCase = ToggleHabitCompletionUseCase(repository: repository, calendar: TestCalendar.fixed)

        try await useCase.execute(habitId: "meditar", date: TestCalendar.today, today: TestCalendar.today)

        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.today))
        #expect(try await repository.isCompleted(habitId: "leer", date: TestCalendar.today) == false)
    }

    // MARK: - Retroactive marking (the reason the guards exist)

    @Test("se puede corregir cualquier día pasado dentro del rango", arguments: [-1, -5, -14, -29, -30])
    func pastDaysInsideTheRangeCanBeMarked(offset: Int) async throws {
        // The fixture habit starts 30 days before `today`, so -30 is its very first day.
        let (useCase, repository) = makeSUT()

        let completed = try await useCase.execute(
            habitId: "meditar", date: TestCalendar.day(offset), today: TestCalendar.today
        )

        #expect(completed)
        #expect(try await repository.isCompleted(habitId: "meditar", date: TestCalendar.day(offset)))
    }

    // MARK: - Guards, mirroring Android's ToggleCompletionResult

    @Test("un hábito inexistente se rechaza sin escribir nada")
    func unknownHabitIsRejected() async throws {
        let (useCase, repository) = makeSUT()

        await #expect(throws: ToggleCompletionError.habitNotFound) {
            try await useCase.execute(habitId: "no-existe", date: TestCalendar.today, today: TestCalendar.today)
        }

        #expect(repository.completionCount(habitId: "no-existe") == 0)
    }

    @Test("un día futuro se rechaza", arguments: [1, 2, 5, 400])
    func futureDatesAreRejected(offset: Int) async throws {
        let (useCase, repository) = makeSUT()

        await #expect(throws: ToggleCompletionError.futureDate) {
            try await useCase.execute(
                habitId: "meditar", date: TestCalendar.day(offset), today: TestCalendar.today
            )
        }

        #expect(repository.completionCount(habitId: "meditar") == 0)
    }

    @Test("hoy más tarde no cuenta como futuro")
    func laterTodayIsNotAFutureDay() async throws {
        // `today` read at 09:00, day tapped is the same date at 23:59 — same calendar day, so
        // it must be accepted. This is the case Android never sees, because LocalDate has no time.
        let (useCase, _) = makeSUT()

        let completed = try await useCase.execute(
            habitId: "meditar",
            date: TestCalendar.day(0, hour: 23, minute: 59),
            today: TestCalendar.day(0, hour: 9)
        )

        #expect(completed)
    }

    @Test("un día anterior al inicio del hábito se rechaza", arguments: [-31, -40, -365])
    func daysBeforeStartAreRejected(offset: Int) async throws {
        let (useCase, repository) = makeSUT()

        await #expect(throws: ToggleCompletionError.outsideHabitRange) {
            try await useCase.execute(
                habitId: "meditar", date: TestCalendar.day(offset), today: TestCalendar.today
            )
        }

        #expect(repository.completionCount(habitId: "meditar") == 0)
    }

    @Test("un día posterior a la fecha de fin se rechaza")
    func daysAfterEndAreRejected() async throws {
        let habit = HabitFixture.make(
            id: "meditar",
            startDate: TestCalendar.day(-30),
            endDate: TestCalendar.day(-10)
        )
        let (useCase, repository) = makeSUT(habit: habit)

        await #expect(throws: ToggleCompletionError.outsideHabitRange) {
            try await useCase.execute(
                habitId: "meditar", date: TestCalendar.day(-9), today: TestCalendar.today
            )
        }

        #expect(repository.completionCount(habitId: "meditar") == 0)
    }

    @Test("el último día del rango sí se puede marcar")
    func theLastDayOfTheRangeIsMarkable() async throws {
        let habit = HabitFixture.make(
            id: "meditar",
            startDate: TestCalendar.day(-30),
            endDate: TestCalendar.day(-10)
        )
        let (useCase, _) = makeSUT(habit: habit)

        let completed = try await useCase.execute(
            habitId: "meditar", date: TestCalendar.day(-10), today: TestCalendar.today
        )

        #expect(completed)
    }

    @Test("el orden de las guardas es el de Android: inexistente gana sobre futuro")
    func notFoundWinsOverFutureDate() async throws {
        let (useCase, _) = makeSUT()

        await #expect(throws: ToggleCompletionError.habitNotFound) {
            try await useCase.execute(habitId: "no-existe", date: TestCalendar.day(+5), today: TestCalendar.today)
        }
    }

    @Test("el orden de las guardas es el de Android: futuro gana sobre fuera de rango")
    func futureDateWinsOverOutsideRange() async throws {
        // A day that is both after `endDate` and after `today` must report FutureDate,
        // matching Android's guard order.
        let habit = HabitFixture.make(
            id: "meditar",
            startDate: TestCalendar.day(-30),
            endDate: TestCalendar.day(-10)
        )
        let (useCase, _) = makeSUT(habit: habit)

        await #expect(throws: ToggleCompletionError.futureDate) {
            try await useCase.execute(habitId: "meditar", date: TestCalendar.day(+3), today: TestCalendar.today)
        }
    }
}
