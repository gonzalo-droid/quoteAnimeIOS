import Foundation
import Testing
@testable import quoteAnime

/// Mirrors Android's `di/PremiumGate.kt`: FREE_HABIT_LIMIT = 3, UNLIMITED_HABITS = Int.MAX_VALUE.
@Suite("PremiumGate")
struct PremiumGateTests {

    /// Each test gets its own suite so the real user's flag is never read or written.
    private static func isolatedGate() -> (gate: PremiumGate, suiteName: String) {
        let suiteName = "test.premiumgate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (PremiumGate(defaults: defaults), suiteName)
    }

    private static func tearDown(_ suiteName: String) {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test("el límite gratuito es 3, igual que en Android")
    func freeLimitMatchesAndroid() {
        #expect(PremiumGate.freeHabitLimit == 3)
    }

    @Test("por defecto el usuario no es premium")
    func defaultsToFree() {
        let (gate, suite) = Self.isolatedGate()
        defer { Self.tearDown(suite) }

        #expect(gate.isPremium == false)
        #expect(gate.maxActiveHabits == 3)
    }

    @Test("en premium los hábitos son ilimitados")
    func premiumIsUnlimited() {
        let (gate, suite) = Self.isolatedGate()
        defer { Self.tearDown(suite) }

        gate.isPremium = true

        #expect(gate.maxActiveHabits == Int.max)
    }

    @Test("quitar premium devuelve el límite gratuito")
    func revokingPremiumRestoresLimit() {
        let (gate, suite) = Self.isolatedGate()
        defer { Self.tearDown(suite) }

        gate.isPremium = true
        gate.isPremium = false

        #expect(gate.maxActiveHabits == PremiumGate.freeHabitLimit)
    }

    @Test("maxActiveHabits según el plan", arguments: [(false, 3), (true, Int.max)])
    func maxActiveHabitsByPlan(isPremium: Bool, expected: Int) {
        let (gate, suite) = Self.isolatedGate()
        defer { Self.tearDown(suite) }

        gate.isPremium = isPremium

        #expect(gate.maxActiveHabits == expected)
    }
}
