import Foundation
import Testing
@testable import quoteAnime

/// What actually grants premium. `StoreKit.Transaction` cannot be built in a unit test, so the
/// adapter maps every entitlement into `EntitlementSnapshot` and this — the deciding part — is
/// pure.
///
/// Android's equivalent is one line (`purchases.any { it.purchaseState == PURCHASED }`) because
/// Android verifies nothing. The extra cases here are the ones StoreKit lets us actually check.
@Suite("Entitlement premium")
struct PremiumEntitlementTests {

    private static let now = Date(timeIntervalSince1970: 1_700_000_000)
    private static let past = now.addingTimeInterval(-86_400)
    private static let future = now.addingTimeInterval(86_400)

    private static func snapshot(
        productId: String = PremiumProducts.subscriptionId,
        isVerified: Bool = true,
        revocationDate: Date? = nil,
        expirationDate: Date? = PremiumEntitlementTests.future,
        keepsAccessPastExpiry: Bool = false,
        isUpgraded: Bool = false
    ) -> EntitlementSnapshot {
        EntitlementSnapshot(
            productId: productId,
            isVerified: isVerified,
            revocationDate: revocationDate,
            expirationDate: expirationDate,
            keepsAccessPastExpiry: keepsAccessPastExpiry,
            isUpgraded: isUpgraded
        )
    }

    private static func decide(_ snapshots: [EntitlementSnapshot]) -> Bool {
        PremiumEntitlementDecision.isPremium(from: snapshots, now: now)
    }

    // MARK: - The five states the product cares about

    @Test("sin suscripción no hay premium")
    func noSubscription() {
        #expect(Self.decide([]) == false)
    }

    @Test("una suscripción activa da premium")
    func activeSubscription() {
        #expect(Self.decide([Self.snapshot()]) == true)
    }

    @Test("una suscripción vencida no da premium")
    func expiredSubscription() {
        #expect(Self.decide([Self.snapshot(expirationDate: Self.past)]) == false)
    }

    @Test("en período de gracia se conserva el premium aunque la fecha ya pasó")
    func gracePeriodKeepsPremium() {
        #expect(Self.decide([Self.snapshot(expirationDate: Self.past, keepsAccessPastExpiry: true)]) == true)
    }

    /// The whole point of not porting Android's client-only check: a transaction whose signature
    /// does not verify must buy nothing, however active it claims to be.
    @Test("una transacción sin verificar NUNCA da premium")
    func unverifiedNeverGrantsPremium() {
        #expect(Self.decide([Self.snapshot(isVerified: false)]) == false)
        #expect(Self.decide([Self.snapshot(isVerified: false, keepsAccessPastExpiry: true)]) == false)
        #expect(Self.decide([Self.snapshot(isVerified: false, expirationDate: nil)]) == false)
    }

    // MARK: - The rest of what StoreKit can say

    @Test("una compra reembolsada o revocada no da premium")
    func revokedSubscription() {
        #expect(Self.decide([Self.snapshot(revocationDate: Self.past)]) == false)
    }

    @Test("una transacción sustituida por otra no da premium por sí sola")
    func upgradedTransaction() {
        #expect(Self.decide([Self.snapshot(isUpgraded: true)]) == false)
    }

    @Test("otro producto no da premium")
    func anotherProduct() {
        #expect(Self.decide([Self.snapshot(productId: "otra_cosa")]) == false)
    }

    @Test("sin fecha de expiración el entitlement no caduca")
    func nonExpiringEntitlement() {
        #expect(Self.decide([Self.snapshot(expirationDate: nil)]) == true)
    }

    @Test("basta con que una del conjunto sirva")
    func anyValidSnapshotWins() {
        let snapshots = [
            Self.snapshot(isVerified: false),
            Self.snapshot(expirationDate: Self.past),
            Self.snapshot()
        ]

        #expect(Self.decide(snapshots) == true)
    }

    @Test("un conjunto entero de entitlements inválidos no da premium")
    func allInvalidSnapshots() {
        let snapshots = [
            Self.snapshot(isVerified: false),
            Self.snapshot(revocationDate: Self.past),
            Self.snapshot(expirationDate: Self.past),
            Self.snapshot(productId: "otra_cosa")
        ]

        #expect(Self.decide(snapshots) == false)
    }

    @Test("el id del producto es el mismo que en Android")
    func productIdMatchesAndroid() {
        #expect(PremiumProducts.subscriptionId == "premium_subscription")
    }
}
