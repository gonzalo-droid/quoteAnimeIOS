import Foundation
import StoreKit

/// Pure part of the product → paywall mapping, so the numbers the paywall shows can be tested
/// without StoreKit (whose `Product` cannot be constructed in a unit test).
enum PremiumOfferMapper {
    /// Android derives trial days with a regex over the ISO-8601 period and the same rough
    /// month/year lengths; the value is only ever used to say "N días de prueba gratis".
    static func trialDays(unit: SubscriptionOffer.PeriodUnit, value: Int) -> Int {
        switch unit {
        case .day:   return value
        case .week:  return value * 7
        case .month: return value * 30
        case .year:  return value * 365
        }
    }
}

/// Buying premium, through StoreKit 2. Mirrors Android's `BillingRepository`, minus everything
/// that only exists because Play needs it.
final class StoreKitPremiumStore: PremiumStore {
    private let entitlementSource: PremiumEntitlementSource

    init(entitlementSource: PremiumEntitlementSource) {
        self.entitlementSource = entitlementSource
    }

    // MARK: - PremiumStore

    func loadOffers() async -> [SubscriptionOffer] {
        do {
            let products = try await Product.products(for: [PremiumProducts.subscriptionId])
            return products.compactMap(Self.offer(from:))
        } catch {
            print("[StoreKitPremiumStore] loadOffers failed: \(error)")
            return []
        }
    }

    func purchase(_ offer: SubscriptionOffer) async -> PremiumPurchaseOutcome {
        do {
            let products = try await Product.products(for: [offer.id])
            guard let product = products.first else { return .failed(.storeUnavailable) }

            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // StoreKit's nearest equivalent to Play's acknowledgement: it tells the store
                    // the content was delivered. Local, cannot fail over the network, so there is
                    // no 72-hour deadline and no retry worker to port.
                    await transaction.finish()
                    await entitlementSource.refresh()
                    return .success
                case .unverified(_, let error):
                    // Android would have granted premium here. We do not: an unverified
                    // transaction is exactly the forgery StoreKit's signature check exists to catch.
                    print("[StoreKitPremiumStore] unverified purchase: \(error)")
                    return .failed(.unverified)
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed(.unknown)
            }
        } catch {
            return Self.outcome(for: error)
        }
    }

    func restore() async -> PremiumRestoreOutcome {
        var syncError: Error?
        do {
            try await AppStore.sync()
        } catch {
            syncError = error
        }

        await entitlementSource.refresh()
        if entitlementSource.isPremium { return .restored }
        if let syncError {
            if case .userCancelled? = syncError as? StoreKitError { return .nothingToRestore }
            print("[StoreKitPremiumStore] restore failed: \(syncError)")
            return .failed(Self.reason(for: syncError))
        }
        return .nothingToRestore
    }

    // MARK: - Mapping

    static func offer(from product: Product) -> SubscriptionOffer? {
        guard let subscription = product.subscription,
              let unit = SubscriptionOffer.PeriodUnit(subscription.subscriptionPeriod.unit) else {
            return nil
        }

        var freeTrialDays: Int?
        if let intro = subscription.introductoryOffer,
           intro.paymentMode == .freeTrial,
           let introUnit = SubscriptionOffer.PeriodUnit(intro.period.unit) {
            freeTrialDays = PremiumOfferMapper.trialDays(unit: introUnit, value: intro.period.value)
        }

        return SubscriptionOffer(
            id: product.id,
            displayName: product.displayName,
            formattedPrice: product.displayPrice,
            periodUnit: unit,
            periodValue: subscription.subscriptionPeriod.value,
            freeTrialDays: freeTrialDays
        )
    }

    // MARK: - Errors

    private static func outcome(for error: Error) -> PremiumPurchaseOutcome {
        if case .userCancelled? = error as? StoreKitError { return .cancelled }
        return .failed(reason(for: error))
    }

    private static func reason(for error: Error) -> PremiumErrorReason {
        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .networkError:
                return .network
            case .notAvailableInStorefront, .unsupported:
                return .storeUnavailable
            default:
                return .unknown
            }
        }
        if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .productUnavailable, .purchaseNotAllowed:
                return .storeUnavailable
            default:
                return .unknown
            }
        }
        if let urlError = error as? URLError {
            _ = urlError
            return .network
        }
        return .unknown
    }
}

private extension SubscriptionOffer.PeriodUnit {
    init?(_ unit: Product.SubscriptionPeriod.Unit) {
        switch unit {
        case .day:   self = .day
        case .week:  self = .week
        case .month: self = .month
        case .year:  self = .year
        @unknown default: return nil
        }
    }
}
