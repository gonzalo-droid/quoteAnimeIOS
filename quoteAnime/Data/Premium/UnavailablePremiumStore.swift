import Foundation

/// The purchasing side while `PremiumConfig.usesRealBilling` is `false`: there is nothing to buy.
///
/// The paywall in "Próximamente" mode never calls it — this exists so the composition root can
/// hand the paywall a `PremiumStore` without constructing `StoreKitPremiumStore`. If something
/// does call it, it answers as an empty store would, and never reaches the App Store.
final class UnavailablePremiumStore: PremiumStore {
    func loadOffers() async -> [SubscriptionOffer] { [] }

    func purchase(_ offer: SubscriptionOffer) async -> PremiumPurchaseOutcome {
        .failed(.storeUnavailable)
    }

    func restore() async -> PremiumRestoreOutcome { .nothingToRestore }
}
