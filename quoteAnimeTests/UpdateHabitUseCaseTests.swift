import Foundation
import Testing
@testable import quoteAnime

/// Editing runs the same validation as creating, minus the plan limit — mirrors Android's
/// `UpdateHabitUseCase` (`HabitNotFound` / `BlankTitle` / `InvalidDateRange`).
@Suite("UpdateHabitUseCase")
struct UpdateHabitUseCaseTests {

    private func makeSUT(seed: [Habit] = [HabitFixture.make(id: "meditar", title: "Meditar")])
        -> (UpdateHabitUseCase, FakeHabitRepository) {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: seed)
        return (UpdateHabitUseCase(repository: repository, calendar: TestCalendar.fixed), repository)
    }

    @Test("editar un hábito existente guarda los cambios")
    func updatesAnExistingHabit() async throws {
        let (useCase, repository) = makeSUT()

        try await useCase.execute(HabitFixture.make(id: "meditar", title: "Meditar 20 min"))

        #expect(try await repository.fetchHabit(id: "meditar")?.title == "Meditar 20 min")
        #expect(repository.habits.count == 1, "no debe duplicar")
    }

    @Test("editar un hábito que no existe se rechaza")
    func unknownHabitIsRejected() async throws {
        let (useCase, repository) = makeSUT()

        await #expect(throws: UpdateHabitError.habitNotFound) {
            try await useCase.execute(HabitFixture.make(id: "fantasma"))
        }

        #expect(repository.habits.count == 1, "no debe crearse por la puerta de atrás")
    }

    @Test("un título vacío se rechaza", arguments: ["", "   ", "\n"])
    func blankTitleIsRejected(title: String) async throws {
        let (useCase, repository) = makeSUT()

        await #expect(throws: UpdateHabitError.blankTitle) {
            try await useCase.execute(HabitFixture.make(id: "meditar", title: title))
        }

        #expect(try await repository.fetchHabit(id: "meditar")?.title == "Meditar", "el título viejo se conserva")
    }

    @Test("una fecha de fin anterior a la de inicio se rechaza")
    func invalidRangeIsRejected() async throws {
        let (useCase, repository) = makeSUT()

        let edited = HabitFixture.make(
            id: "meditar",
            startDate: TestCalendar.day(0),
            endDate: TestCalendar.day(-3)
        )

        await #expect(throws: UpdateHabitError.invalidDateRange) {
            try await useCase.execute(edited)
        }

        #expect(try await repository.fetchHabit(id: "meditar")?.endDate == nil)
    }

    @Test("ponerle fecha de fin a un hábito existente funciona")
    func addingAnEndDateWorks() async throws {
        let (useCase, repository) = makeSUT()

        let edited = HabitFixture.make(
            id: "meditar",
            startDate: TestCalendar.day(-30),
            endDate: TestCalendar.day(+10)
        )
        try await useCase.execute(edited)

        let stored = try await repository.fetchHabit(id: "meditar")
        #expect(stored?.endDate != nil)
        #expect(stored?.isActiveOn(TestCalendar.day(+11), calendar: TestCalendar.fixed) == false)
    }

    @Test("editar un hábito archivado no lo restaura")
    func editingAnArchivedHabitKeepsItArchived() async throws {
        // `saveHabit` upserts the whole record (Android does the same), so the caller must
        // carry `isArchived` forward. This pins the contract the editor depends on.
        let (useCase, repository) = makeSUT(
            seed: [HabitFixture.make(id: "meditar", title: "Meditar", isArchived: true)]
        )

        let edited = HabitFixture.make(id: "meditar", title: "Meditar más", isArchived: true)
        try await useCase.execute(edited)

        #expect(try await repository.fetchArchivedHabits().count == 1)
        #expect(try await repository.countActiveHabits() == 0)
    }

    @Test("el título se guarda sin espacios sobrantes")
    func titleIsTrimmed() async throws {
        let (useCase, repository) = makeSUT()

        let saved = try await useCase.execute(HabitFixture.make(id: "meditar", title: "  Leer  "))

        #expect(saved.title == "Leer")
        #expect(try await repository.fetchHabit(id: "meditar")?.title == "Leer")
    }
}
