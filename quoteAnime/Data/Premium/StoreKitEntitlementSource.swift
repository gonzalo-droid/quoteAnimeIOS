import Foundation
import Combine
import StoreKit

/// Premium entitlement, straight from StoreKit 2.
///
/// `Transaction.currentEntitlements` is the source of truth, re-read at launch and on every
/// return to the foreground — the same two moments Android re-syncs with Play. `Transaction.updates`
/// covers everything that happens while the app is not asking: a renewal, a refund, a
/// cancellation made in Settings, a purchase completed on another device.
///
/// The last answer is cached in `UserDefaults` only so a cold launch does not show a paying user
/// the free UI for the frame before StoreKit answers. The cache is never preferred over the store.
final class StoreKitEntitlementSource: PremiumEntitlementSource {
    /// Deliberately **not** `pref_is_premium`. That key belongs to the pre-billing mock, whose
    /// "Suscribirme" button granted premium locally to anyone who tapped it; reusing it would
    /// hand every one of those users a premium cache on the first launch of this build.
    private static let cacheKey = "pref_premium_entitlement_cache"

    private let defaults: UserDefaults
    private let subject: CurrentValueSubject<Bool, Never>
    private var updatesTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.subject = CurrentValueSubject(defaults.bool(forKey: Self.cacheKey))
        listenForStoreUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - PremiumEntitlementSource

    var isPremium: Bool { subject.value }

    var isPremiumPublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }

    func refresh() async {
        var entitlements: [StoreKit.Transaction] = []
        var unverified: [StoreKit.Transaction] = []

        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                entitlements.append(transaction)
            case .unverified(let transaction, let error):
                print("[StoreKitEntitlementSource] unverified entitlement \(transaction.productID): \(error)")
                unverified.append(transaction)
            }
        }

        // The grace-period lookup is a network call, so it only happens when it can change the
        // answer: some entitlement StoreKit still lists has an expiry date already behind us.
        let now = Date()
        let hasExpiredEntitlement = entitlements.contains { expiry in
            guard let expirationDate = expiry.expirationDate else { return false }
            return expirationDate <= now
        }
        let keepsAccess = hasExpiredEntitlement ? await storeKeepsAccessPastExpiry() : false

        let snapshots =
            entitlements.map { Self.snapshot(from: $0, isVerified: true, keepsAccessPastExpiry: keepsAccess) }
            + unverified.map { Self.snapshot(from: $0, isVerified: false, keepsAccessPastExpiry: keepsAccess) }

        apply(PremiumEntitlementDecision.isPremium(from: snapshots, now: now))
    }

    // MARK: - Internals

    private func apply(_ newValue: Bool) {
        defaults.set(newValue, forKey: Self.cacheKey)
        guard subject.value != newValue else { return }
        subject.send(newValue)
    }

    private static func snapshot(
        from transaction: StoreKit.Transaction,
        isVerified: Bool,
        keepsAccessPastExpiry: Bool
    ) -> EntitlementSnapshot {
        EntitlementSnapshot(
            productId: transaction.productID,
            isVerified: isVerified,
            revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate,
            keepsAccessPastExpiry: keepsAccessPastExpiry,
            isUpgraded: transaction.isUpgraded
        )
    }

    /// Whether the subscription is in billing grace period or billing retry, i.e. the store still
    /// grants access after the expiry date.
    ///
    /// When the lookup itself fails this returns `true`: `currentEntitlements` already vouched for
    /// the transaction, and a flaky network must never be what revokes a paying user's premium.
    private func storeKeepsAccessPastExpiry() async -> Bool {
        do {
            let products = try await Product.products(for: [PremiumProducts.subscriptionId])
            guard let subscription = products.first?.subscription else { return false }
            let statuses = try await subscription.status
            return statuses.contains { $0.state == .inGracePeriod || $0.state == .inBillingRetryPeriod }
        } catch {
            print("[StoreKitEntitlementSource] renewal state unavailable, keeping access: \(error)")
            return true
        }
    }

    /// Never cancelled while the app runs — a transaction that arrives with no listener attached
    /// is redelivered on the next launch, but the user would have waited until then for premium.
    private func listenForStoreUpdates() {
        updatesTask = Task.detached { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    // The nearest thing StoreKit has to Play's acknowledgement. It is a local
                    // call that cannot fail over the network, so there is no 72-hour deadline
                    // and no retry worker to port — see PARITY.md.
                    await transaction.finish()
                }
                await self.refresh()
            }
        }
    }
}
