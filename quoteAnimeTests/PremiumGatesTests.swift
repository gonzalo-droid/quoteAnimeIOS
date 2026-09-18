import Foundation
import Testing
@testable import quoteAnime

/// The three things premium actually buys. Their rules did not change when StoreKit landed —
/// only where `isPremium` comes from — so what these pin is that each one still follows the
/// entitlement, and that losing premium blocks rather than destroys.
@Suite("Gates premium")
struct PremiumGatesTests {

    // MARK: - 1. The active-habit limit

    @Test("en gratuito el cuarto hábito se rechaza; en premium no")
    func habitLimitFollowsTheEntitlement() async throws {
        for premium in [false, true] {
            let repository = FakeHabitRepository()
            repository.seed(habits: HabitFixture.makeMany(PremiumGate.freeHabitLimit))
            let useCase = CreateHabitUseCase(
                repository: repository,
                premiumGate: PremiumGate.fake(premium: premium)
            )

            if premium {
                try await useCase.execute(HabitFixture.make(id: "cuarto"))
                #expect(try await repository.countActiveHabits() == PremiumGate.freeHabitLimit + 1)
            } else {
                await #expect(throws: CreateHabitError.habitLimitReached(max: PremiumGate.freeHabitLimit)) {
                    try await useCase.execute(HabitFixture.make(id: "cuarto"))
                }
                #expect(try await repository.countActiveHabits() == PremiumGate.freeHabitLimit)
            }
        }
    }

    /// The behaviour the user sees when a subscription lapses. Android keeps every habit and only
    /// refuses the *next* creation — there is no code path anywhere near `setPremium(false)` that
    /// deletes or archives anything — and iOS must do the same. Losing a subscription is not a
    /// reason to lose data.
    @Test("al perder premium los hábitos de más NO se borran: sólo se bloquea crear otro")
    func losingPremiumKeepsExistingHabits() async throws {
        let source = FakeEntitlementSource(isPremium: true)
        let gate = PremiumGate(source: source)
        let repository = FakeHabitRepository()
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        repository.seed(habits: HabitFixture.makeMany(PremiumGate.freeHabitLimit))
        try await useCase.execute(HabitFixture.make(id: "cuarto"))
        let countWhilePremium = try await repository.countActiveHabits()
        #expect(countWhilePremium == PremiumGate.freeHabitLimit + 1)

        source.set(false)

        #expect(try await repository.countActiveHabits() == countWhilePremium)
        let survivors = try await GetActiveHabitsUseCase(repository: repository).execute()
        #expect(survivors.contains { $0.habit.id == "cuarto" })

        await #expect(throws: CreateHabitError.habitLimitReached(max: PremiumGate.freeHabitLimit)) {
            try await useCase.execute(HabitFixture.make(id: "quinto"))
        }
    }

    @Test("el gate deja de bloquear en cuanto la tienda confirma la compra")
    func buyingPremiumUnblocksCreation() async throws {
        let source = FakeEntitlementSource(isPremium: false)
        let gate = PremiumGate(source: source)
        let repository = FakeHabitRepository()
        repository.seed(habits: HabitFixture.makeMany(PremiumGate.freeHabitLimit))
        let useCase = CreateHabitUseCase(repository: repository, premiumGate: gate)

        source.set(true)

        try await useCase.execute(HabitFixture.make(id: "cuarto"))
        #expect(try await repository.countActiveHabits() == PremiumGate.freeHabitLimit + 1)
    }

    // MARK: - 2. Premium templates

    @Test("en gratuito sólo Pokémon y Black Clover están bloqueadas")
    func lockedTemplatesForFreeUsers() {
        let locked = DefaultHabitTemplates.all.filter { $0.isLocked(isPremium: false) }

        #expect(Set(locked.map(\.id)) == ["theme_pokemon", "theme_black_clover"])
    }

    @Test("en premium no queda ninguna plantilla bloqueada")
    func noLockedTemplatesForPremium() {
        #expect(DefaultHabitTemplates.all.allSatisfy { !$0.isLocked(isPremium: true) })
    }

    @Test("las tres plantillas originales siguen siendo gratuitas")
    func originalTemplatesStayFree() {
        let free = DefaultHabitTemplates.all.filter { !$0.isLocked(isPremium: false) }

        #expect(Set(free.map(\.id)) == ["theme_ninja", "theme_one_piece", "theme_saiyan"])
    }

    // MARK: - 3. Ads

    @Test("en premium ninguna compartida muestra anuncio")
    func premiumNeverSeesAnInterstitial() {
        var policy = ShareAdPolicy()

        for _ in 0..<10 {
            #expect(policy.shouldShowAd(isPremium: true) == false)
        }
    }

    @Test("en gratuito el anuncio aparece cada 3 compartidas, como en Android")
    func freeUserSeesAnAdEveryThirdShare() {
        var policy = ShareAdPolicy()

        let results = (1...9).map { _ in policy.shouldShowAd(isPremium: false) }

        #expect(results == [false, false, true, false, false, true, false, false, true])
    }

    /// The counter must not run while the user is paying: otherwise the very first share after a
    /// cancellation could land on an ad slot the user never "used".
    @Test("el contador no corre mientras el usuario es premium")
    func counterDoesNotRunWhilePremium() {
        var policy = ShareAdPolicy()

        _ = policy.shouldShowAd(isPremium: true)
        _ = policy.shouldShowAd(isPremium: true)
        let afterCancelling = (1...3).map { _ in policy.shouldShowAd(isPremium: false) }

        #expect(afterCancelling == [false, false, true])
    }
}
