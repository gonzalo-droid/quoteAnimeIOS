import Foundation
@testable import quoteAnime

/// The purchasing side of premium, driven by the test. Mirrors what StoreKit would do on the way
/// back: a successful purchase or restore flips the entitlement source it was given.
final class FakePremiumStore: PremiumStore {
    var offers: [SubscriptionOffer] = []
    var purchaseOutcome: PremiumPurchaseOutcome = .success
    var restoreOutcome: PremiumRestoreOutcome = .nothingToRestore

    private(set) var purchasedOffers: [SubscriptionOffer] = []
    private(set) var loadOffersCount = 0
    private(set) var restoreCount = 0

    /// Flipped on a successful purchase or restore, the way `Transaction.currentEntitlements`
    /// would answer differently afterwards.
    var entitlementSource: FakeEntitlementSource?

    func loadOffers() async -> [SubscriptionOffer] {
        loadOffersCount += 1
        return offers
    }

    func purchase(_ offer: SubscriptionOffer) async -> PremiumPurchaseOutcome {
        purchasedOffers.append(offer)
        if purchaseOutcome == .success { entitlementSource?.set(true) }
        return purchaseOutcome
    }

    func restore() async -> PremiumRestoreOutcome {
        restoreCount += 1
        if restoreOutcome == .restored { entitlementSource?.set(true) }
        return restoreOutcome
    }
}

enum SubscriptionOfferFixture {
    static func make(
        id: String = PremiumProducts.subscriptionId,
        displayName: String = "Premium",
        formattedPrice: String = "4,99 €",
        periodUnit: SubscriptionOffer.PeriodUnit = .month,
        periodValue: Int = 1,
        freeTrialDays: Int? = nil
    ) -> SubscriptionOffer {
        SubscriptionOffer(
            id: id,
            displayName: displayName,
            formattedPrice: formattedPrice,
            periodUnit: periodUnit,
            periodValue: periodValue,
            freeTrialDays: freeTrialDays
        )
    }
}
