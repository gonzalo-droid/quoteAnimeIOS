import Foundation
import Testing
@testable import quoteAnime

/// Mirrors Android's `di/PremiumGate.kt`: FREE_HABIT_LIMIT = 3, UNLIMITED_HABITS = Int.MAX_VALUE.
///
/// Since StoreKit landed the gate no longer owns the answer — it proxies a
/// `PremiumEntitlementSource`. These tests drive that source by hand; what StoreKit puts in it is
/// `PremiumEntitlementTests`' job.
@Suite("PremiumGate")
struct PremiumGateTests {

    @Test("el límite gratuito es 3, igual que en Android")
    func freeLimitMatchesAndroid() {
        #expect(PremiumGate.freeHabitLimit == 3)
    }

    @Test("por defecto el usuario no es premium")
    func defaultsToFree() {
        let gate = PremiumGate.fake()

        #expect(gate.isPremium == false)
        #expect(gate.maxActiveHabits == 3)
    }

    @Test("en premium los hábitos son ilimitados")
    func premiumIsUnlimited() {
        let gate = PremiumGate.fake(premium: true)

        #expect(gate.maxActiveHabits == Int.max)
    }

    @Test("maxActiveHabits según el plan", arguments: [(false, 3), (true, Int.max)])
    func maxActiveHabitsByPlan(isPremium: Bool, expected: Int) {
        let gate = PremiumGate.fake(premium: isPremium)

        #expect(gate.maxActiveHabits == expected)
    }

    @Test("cuando la tienda retira el entitlement el límite vuelve al gratuito")
    func revokingPremiumRestoresLimit() {
        let source = FakeEntitlementSource(isPremium: true)
        let gate = PremiumGate(source: source)
        #expect(gate.maxActiveHabits == Int.max)

        source.set(false)

        #expect(gate.isPremium == false)
        #expect(gate.maxActiveHabits == PremiumGate.freeHabitLimit)
    }

    @Test("con los pagos apagados no hay límite de hábitos, pero isPremium sigue siendo el real")
    func paymentsOffLiftsLimits() {
        let gate = PremiumGate(source: FakeEntitlementSource(isPremium: false), paymentsEnabled: false)

        #expect(gate.maxActiveHabits == Int.max)
        #expect(gate.unlocksPremiumFeatures == true)
        // Los anuncios leen isPremium: tienen que seguir apareciendo.
        #expect(gate.isPremium == false)
    }

    @Test("con los pagos encendidos las sugerencias premium siguen con candado")
    func paymentsOnKeepsLocks() {
        let gate = PremiumGate.fake()
        let premiumOnly = HabitTemplate(
            id: "t", title: "t", iconKey: "star", order: 0,
            themeColorIndex: nil, themeKey: nil, isPremiumOnly: true
        )

        #expect(premiumOnly.isLocked(isPremium: gate.unlocksPremiumFeatures) == true)
        let free = PremiumGate(source: FakeEntitlementSource(), paymentsEnabled: false)
        #expect(premiumOnly.isLocked(isPremium: free.unlocksPremiumFeatures) == false)
    }

    @Test("el build que se publica tiene los pagos apagados")
    func shippedBuildHasPaymentsOff() {
        // Cambiar junto con PremiumConfig.paymentsEnabled cuando la suscripción exista en App Store Connect.
        #expect(PremiumConfig.paymentsEnabled == false)
        #expect(PremiumServices.live.gate.paymentsEnabled == false)
    }

    @Test("el gate no guarda copia: lee siempre la fuente")
    func readsThroughToTheSource() {
        let source = FakeEntitlementSource(isPremium: false)
        let gate = PremiumGate(source: source)

        source.set(true)

        #expect(gate.isPremium == true)
    }

    @Test("refresh delega en la fuente")
    func refreshForwardsToTheSource() async {
        let source = FakeEntitlementSource()
        let gate = PremiumGate(source: source)

        await gate.refresh()
        await gate.refresh()

        #expect(source.refreshCount == 2)
    }
}
