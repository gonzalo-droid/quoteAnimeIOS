import Foundation

/// One purchasable plan, as the paywall needs to show it.
///
/// Mirrors Android's `SubscriptionOffer`, except the price is already formatted for the user's
/// locale by the store (Android's `formattedPrice` is too) and the period is a unit plus a count
/// rather than the raw ISO-8601 string Android puts on screen (`"P1M"`). Nothing here is
/// hardcoded: the catalogue lives in App Store Connect, or in the local `.storekit` file while
/// testing.
struct SubscriptionOffer: Identifiable, Hashable {
    enum PeriodUnit: Hashable {
        case day, week, month, year
    }

    /// The store product id — also the `Identifiable` id, since the app sells a single product.
    let id: String
    let displayName: String
    /// Already localised by the store, currency symbol included. Never reformatted.
    let formattedPrice: String
    let periodUnit: PeriodUnit
    let periodValue: Int
    /// Days of introductory free trial, or `nil` when the plan has none.
    let freeTrialDays: Int?
}

/// Why a purchase or a restore did not go through, at the granularity the user is told about.
///
/// Mirrors Android's `BillingErrorReason` plus `unverified`, which has no Android counterpart
/// because Android never verifies anything. The store's own debug text is deliberately kept out
/// of the UI — it is English, internal, and written for developers.
enum PremiumErrorReason: Equatable {
    case network
    case storeUnavailable
    /// StoreKit handed over a transaction whose signature did not check out.
    case unverified
    case unknown
}

enum PremiumPurchaseOutcome: Equatable {
    case success
    /// Ask to Buy, or a payment that needs the bank's confirmation. Entitlement arrives later
    /// through `Transaction.updates`, exactly as Android's `PENDING` arrives through Play.
    case pending
    case cancelled
    case failed(PremiumErrorReason)
}

enum PremiumRestoreOutcome: Equatable {
    case restored
    case nothingToRestore
    case failed(PremiumErrorReason)
}

/// The purchasing side of premium, mirroring Android's `BillingRepository`. Entitlement itself
/// is not here — that is `PremiumEntitlementSource`, because the gates need it and must not link
/// StoreKit.
protocol PremiumStore: AnyObject {
    /// Empty means "no plans to show" — the paywall's elegant empty state, same as Android's.
    /// Failures are not distinguished from an empty catalogue, because the user can do the same
    /// thing about either.
    func loadOffers() async -> [SubscriptionOffer]

    func purchase(_ offer: SubscriptionOffer) async -> PremiumPurchaseOutcome

    /// App Store Review requires a user-initiated restore; Play does not, so Android has no
    /// equivalent (see `PARITY.md`).
    func restore() async -> PremiumRestoreOutcome
}
