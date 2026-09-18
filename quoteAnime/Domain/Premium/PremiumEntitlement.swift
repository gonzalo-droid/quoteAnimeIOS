import Foundation
import Combine

/// The one place the store product identifier lives — changing the subscription means editing
/// this line and nothing else.
///
/// The string is the same as Android's `BillingRepository.PREMIUM_PRODUCT_ID` by explicit
/// product decision. It is *not* a synchronised value: App Store Connect and Play Console are
/// separate catalogues, so renaming it on one platform does nothing to the other.
enum PremiumProducts {
    static let subscriptionId = "premium_subscription"
}

/// Platform-neutral snapshot of one StoreKit entitlement.
///
/// `StoreKit.Transaction` cannot be constructed in a test, so the adapter maps every entitlement
/// into this struct at the edge and the decision below — the part that actually grants premium —
/// stays pure and testable.
struct EntitlementSnapshot: Equatable {
    let productId: String

    /// `false` when StoreKit handed the transaction over as `VerificationResult.unverified`,
    /// i.e. its signature did not check out. Android has no equivalent: it trusts whatever Play
    /// reports as `PURCHASED`, and that is the weakness we deliberately do not port.
    let isVerified: Bool

    /// Set by StoreKit when Apple refunded or revoked the purchase.
    let revocationDate: Date?

    /// `nil` for a product that never expires.
    let expirationDate: Date?

    /// The store still grants access even though `expirationDate` has passed — a subscription in
    /// billing grace period or billing retry. `Transaction.currentEntitlements` lists those, so
    /// the expiry date alone must never be what revokes access.
    let keepsAccessPastExpiry: Bool

    /// StoreKit marks a transaction that a newer one superseded, e.g. after a plan change.
    let isUpgraded: Bool
}

/// Whether a set of entitlements grants premium. Pure, synchronous, StoreKit-free.
enum PremiumEntitlementDecision {
    static func isPremium(from snapshots: [EntitlementSnapshot], now: Date = Date()) -> Bool {
        snapshots.contains { grantsPremium($0, now: now) }
    }

    static func grantsPremium(_ snapshot: EntitlementSnapshot, now: Date = Date()) -> Bool {
        guard snapshot.productId == PremiumProducts.subscriptionId else { return false }
        guard snapshot.isVerified else { return false }
        guard snapshot.revocationDate == nil else { return false }
        guard !snapshot.isUpgraded else { return false }
        if snapshot.keepsAccessPastExpiry { return true }
        guard let expirationDate = snapshot.expirationDate else { return true }
        return expirationDate > now
    }
}

/// Where `isPremium` comes from. One implementation reads StoreKit; a second one, compiled only
/// into DEBUG builds, lets QA force the answer without buying anything.
///
/// The protocol exists so the gate, the three feature gates and their tests never link StoreKit.
protocol PremiumEntitlementSource: AnyObject {
    var isPremium: Bool { get }

    /// Emits the current value on subscription and again on every change.
    var isPremiumPublisher: AnyPublisher<Bool, Never> { get }

    /// Re-read the store. Android re-syncs on every process start; its repository documents a
    /// re-sync "on every return to the foreground" too, which its own code never wires up —
    /// iOS does both (see `PARITY.md`).
    func refresh() async
}
