import Foundation
import Testing
@testable import quoteAnime

/// The free-tier cap is enforced here and nowhere else, same as Android's
/// `CreateHabitUseCase` (`repository.countActiveHabits() >= max` → LimitReached).
@Suite("CreateHabitUseCase")
struct CreateHabitUseCaseTests {

    private static func makeGate(premium: Bool) -> (PremiumGate, String) {
        let suiteName = "test.createhabit.\(UUID().uuidString)"
        let gate = PremiumGate(defaults: UserDefaults(suiteName: suiteName)!)
        gate.isPremium = premium
        return (gate, suiteName)
    }

    private static func tearDown(_ suiteName: String) {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    // MARK: - The exact edge of the free limit

    @Test(
        "en plan gratuito se puede crear mientras haya menos de 3 activos",
        arguments: [0, 1, 2]
    )
    func allowsCreationBelowLimit(existingCount: Int) async throws {
        let (gate, suite) = Self.makeGate(premium: false)
        defer { Self.tearDown(suite) }

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(existingCount))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        try await useCase.execute(HabitFixture.make(id: "nuevo"))

        let active = try await repository.countActiveHabits()
        #expect(active == existingCount + 1)
    }

    @Test("con 3 activos el plan gratuito rechaza el cuarto")
    func rejectsAtLimit() async throws {
        let (gate, suite) = Self.makeGate(premium: false)
        defer { Self.tearDown(suite) }

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(3))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        await #expect(throws: CreateHabitError.habitLimitReached) {
            try await useCase.execute(HabitFixture.make(id: "cuarto"))
        }

        let active = try await repository.countActiveHabits()
        #expect(active == 3, "el hábito rechazado no debe guardarse")
    }

    @Test("por encima del límite también se rechaza", arguments: [4, 5, 10])
    func rejectsAboveLimit(existingCount: Int) async throws {
        let (gate, suite) = Self.makeGate(premium: false)
        defer { Self.tearDown(suite) }

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(existingCount))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        await #expect(throws: CreateHabitError.habitLimitReached) {
            try await useCase.execute(HabitFixture.make(id: "extra"))
        }
    }

    // MARK: - Archived habits don't consume the quota

    @Test("los hábitos archivados no cuentan para el límite")
    func archivedDoNotCountTowardsLimit() async throws {
        let (gate, suite) = Self.makeGate(premium: false)
        defer { Self.tearDown(suite) }

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
        let (gate, suite) = Self.makeGate(premium: false)
        defer { Self.tearDown(suite) }

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(3))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        await #expect(throws: CreateHabitError.habitLimitReached) {
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
        let (gate, suite) = Self.makeGate(premium: true)
        defer { Self.tearDown(suite) }

        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(25))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        try await useCase.execute(HabitFixture.make(id: "veintiseis"))

        let active = try await repository.countActiveHabits()
        #expect(active == 26)
    }

    @Test("crear con el mismo id actualiza en vez de duplicar")
    func savingSameIdUpdates() async throws {
        let (gate, suite) = Self.makeGate(premium: false)
        defer { Self.tearDown(suite) }

        let repository = FakeHabitRepository()
        repository.seed(habits: [HabitFixture.make(id: "unico", title: "Original")])
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        try await useCase.execute(HabitFixture.make(id: "unico", title: "Editado"))

        let active = try await repository.fetchActiveHabits()
        #expect(active.count == 1)
        #expect(active.first?.title == "Editado")
    }
}
