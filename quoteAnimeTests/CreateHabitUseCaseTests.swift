import Foundation
import Testing
@testable import quoteAnime

/// The free-tier cap is enforced here and nowhere else, same as Android's
/// `CreateHabitUseCase` (`repository.countActiveHabits() >= max` → LimitReached).
@Suite("CreateHabitUseCase")
struct CreateHabitUseCaseTests {

    // MARK: - The exact edge of the free limit

    @Test(
        "en plan gratuito se puede crear mientras haya menos de 3 activos",
        arguments: [0, 1, 2]
    )
    func allowsCreationBelowLimit(existingCount: Int) async throws {
        let gate = PremiumGate.fake(premium: false)

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(existingCount))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        try await useCase.execute(HabitFixture.make(id: "nuevo"))

        let active = try await repository.countActiveHabits()
        #expect(active == existingCount + 1)
    }

    @Test("con 3 activos el plan gratuito rechaza el cuarto")
    func rejectsAtLimit() async throws {
        let gate = PremiumGate.fake(premium: false)

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(3))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        await #expect(throws: CreateHabitError.habitLimitReached(max: 3)) {
            try await useCase.execute(HabitFixture.make(id: "cuarto"))
        }

        let active = try await repository.countActiveHabits()
        #expect(active == 3, "el hábito rechazado no debe guardarse")
    }

    @Test("por encima del límite también se rechaza", arguments: [4, 5, 10])
    func rejectsAboveLimit(existingCount: Int) async throws {
        let gate = PremiumGate.fake(premium: false)

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(existingCount))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        await #expect(throws: CreateHabitError.habitLimitReached(max: 3)) {
            try await useCase.execute(HabitFixture.make(id: "extra"))
        }
    }

    // MARK: - Archived habits don't consume the quota

    @Test("los hábitos archivados no cuentan para el límite")
    func archivedDoNotCountTowardsLimit() async throws {
        let gate = PremiumGate.fake(premium: false)

        let repository = FakeHabitRepository()
        // 5 habits, but 3 of them archived → only 2 active, so a new one must fit.
        repository.seed(
            habits: HabitFixture.makeMany(5),
            archived: ["habit-2", "habit-3", "habit-4"]
        )
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        try await useCase.execute(HabitFixture.make(id: "nuevo"))

        let active = try await repository.countActiveHabits()
        #expect(active == 3)
    }

    @Test("archivar uno libera cupo para crear otro")
    func archivingFreesASlot() async throws {
        let gate = PremiumGate.fake(premium: false)

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(3))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        await #expect(throws: CreateHabitError.habitLimitReached(max: 3)) {
            try await useCase.execute(HabitFixture.make(id: "bloqueado"))
        }

        try await repository.archiveHabit(id: "habit-0")
        try await useCase.execute(HabitFixture.make(id: "ahora-si"))

        let active = try await repository.countActiveHabits()
        #expect(active == 3)
    }

    // MARK: - Premium

    @Test("en premium no hay límite")
    func premiumHasNoLimit() async throws {
        let gate = PremiumGate.fake(premium: true)

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(25))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        try await useCase.execute(HabitFixture.make(id: "veintiseis"))

        let active = try await repository.countActiveHabits()
        #expect(active == 26)
    }

    @Test("crear con el mismo id actualiza en vez de duplicar")
    func savingSameIdUpdates() async throws {
        let gate = PremiumGate.fake(premium: false)

        let repository = FakeHabitRepository()
        repository.seed(habits: [HabitFixture.make(id: "unico", title: "Original")])
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        try await useCase.execute(HabitFixture.make(id: "unico", title: "Editado"))

        let active = try await repository.fetchActiveHabits()
        #expect(active.count == 1)
        #expect(active.first?.title == "Editado")
    }

    @Test("el error de límite lleva el máximo del plan premium")
    func limitErrorCarriesThePremiumMax() async throws {
        // Premium's max is Int.max, so the only way to hit the branch is to report it — the
        // point of the assertion is that the value travels with the error, as on Android.
        let gate = PremiumGate.fake(premium: false)

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(3))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        do {
            try await useCase.execute(HabitFixture.make(id: "cuarto"))
            Issue.record("debería haber lanzado habitLimitReached")
        } catch let error as CreateHabitError {
            #expect(error == .habitLimitReached(max: PremiumGate.freeHabitLimit))
        }
    }

    // MARK: - Validation, mirroring Android's BlankTitle / InvalidDateRange

    private static func makeSUT(premium: Bool = false) -> (CreateHabitUseCase, FakeHabitRepository) {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        let useCase = CreateHabitUseCase(
            repository: repository,
            premiumGate: PremiumGate.fake(premium: premium),
            calendar: TestCalendar.fixed
        )
        return (useCase, repository)
    }

    @Test("un título vacío o sólo espacios se rechaza", arguments: ["", " ", "   ", "\n", "\t  \n"])
    func blankTitleIsRejected(title: String) async throws {
        let (useCase, repository) = Self.makeSUT()
        await #expect(throws: CreateHabitError.blankTitle) {
            try await useCase.execute(HabitFixture.make(id: "vacio", title: title))
        }

        #expect(try await repository.countActiveHabits() == 0, "no debe guardarse nada")
    }

    @Test("el título se guarda sin espacios sobrantes")
    func titleIsTrimmed() async throws {
        let (useCase, repository) = Self.makeSUT()
        let saved = try await useCase.execute(HabitFixture.make(id: "h", title: "  Meditar 10 min  "))

        #expect(saved.title == "Meditar 10 min")
        #expect(try await repository.fetchHabit(id: "h")?.title == "Meditar 10 min")
    }

    @Test("una descripción en blanco se guarda como nil")
    func blankDescriptionBecomesNil() async throws {
        let (useCase, repository) = Self.makeSUT()
        try await useCase.execute(HabitFixture.make(id: "h", description: "   "))

        #expect(try await repository.fetchHabit(id: "h")?.description == nil)
    }

    @Test("una fecha de fin anterior a la de inicio se rechaza", arguments: [-1, -5, -365])
    func endDateBeforeStartIsRejected(endOffset: Int) async throws {
        let (useCase, repository) = Self.makeSUT()
        let habit = HabitFixture.make(
            id: "invalido",
            startDate: TestCalendar.day(0),
            endDate: TestCalendar.day(endOffset)
        )

        await #expect(throws: CreateHabitError.invalidDateRange) {
            try await useCase.execute(habit)
        }

        #expect(try await repository.countActiveHabits() == 0)
    }

    @Test("una fecha de fin igual a la de inicio se acepta")
    func sameDayRangeIsAccepted() async throws {
        let (useCase, repository) = Self.makeSUT()
        let habit = HabitFixture.make(
            id: "un-dia",
            startDate: TestCalendar.day(0, hour: 20),
            endDate: TestCalendar.day(0, hour: 8)
        )

        try await useCase.execute(habit)

        #expect(try await repository.countActiveHabits() == 1, "mismo día a distinta hora sigue siendo un rango válido")
    }

    @Test("el título vacío se valida antes que el rango de fechas")
    func blankTitleWinsOverDateRange() async throws {
        let (useCase, _) = Self.makeSUT()
        let habit = HabitFixture.make(
            id: "doble-error",
            title: "  ",
            startDate: TestCalendar.day(0),
            endDate: TestCalendar.day(-5)
        )

        await #expect(throws: CreateHabitError.blankTitle) {
            try await useCase.execute(habit)
        }
    }

    @Test("la validación corre antes que el límite del plan")
    func validationRunsBeforeTheLimit() async throws {
        let (useCase, repository) = Self.makeSUT()
        repository.seed(habits: HabitFixture.makeMany(3))

        await #expect(throws: CreateHabitError.blankTitle) {
            try await useCase.execute(HabitFixture.make(id: "cuarto", title: ""))
        }
    }

    @Test("sin recordatorio activo los días se limpian")
    func reminderDaysAreClearedWithoutReminder() async throws {
        let (useCase, repository) = Self.makeSUT()
        let habit = HabitFixture.make(id: "h", reminderEnabled: false, reminderWeekdays: [2, 4, 6])

        try await useCase.execute(habit)

        #expect(try await repository.fetchHabit(id: "h")?.reminderWeekdays.isEmpty == true)
    }

    @Test("con recordatorio activo los días se conservan")
    func reminderDaysSurviveWithReminder() async throws {
        let (useCase, repository) = Self.makeSUT()
        let habit = HabitFixture.make(id: "h", reminderEnabled: true, reminderWeekdays: [2, 4, 6])

        try await useCase.execute(habit)

        #expect(try await repository.fetchHabit(id: "h")?.reminderWeekdays == [2, 4, 6])
    }

    @Test("un recordatorio activo sin días se guarda apagado")
    func reminderWithoutWeekdaysIsSavedOff() async throws {
        let (useCase, repository) = Self.makeSUT()
        let habit = HabitFixture.make(id: "h", reminderEnabled: true, reminderWeekdays: [])

        let saved = try await useCase.execute(habit)

        #expect(saved.reminderEnabled == false)
        #expect(try await repository.fetchHabit(id: "h")?.reminderEnabled == false)
    }
}
