import Foundation

/// Everything premium, built once from `PremiumConfig.usesRealBilling`. The composition root and
/// `PremiumGate.shared` both read `PremiumServices.live`, so the gate, the paywall's store and the
/// "(solo pruebas)" switch always share one entitlement source.
struct PremiumServices {
    let gate: PremiumGate
    let store: PremiumStore
    let purchaseAvailability: PremiumPurchaseAvailability
    /// `nil` where no test switch can exist at all: a release build with real billing.
    let testControls: TestPremiumControlling?

    static let live = make(usesRealBilling: PremiumConfig.usesRealBilling)

    /// The StoreKit types arrive as factories on purpose: with `usesRealBilling == false` they
    /// must not even be constructed — `StoreKitEntitlementSource.init` starts listening to
    /// `Transaction.updates` — and a test proves it by passing factories that fail when called.
    static func make(
        usesRealBilling: Bool,
        defaults: UserDefaults = .standard,
        detector: AppDistributionDetecting = AppTransactionDistributionDetector(),
        makeStoreKitSource: () -> PremiumEntitlementSource = { StoreKitEntitlementSource() },
        makeStoreKitStore: (PremiumEntitlementSource) -> PremiumStore = {
            StoreKitPremiumStore(entitlementSource: $0)
        }
    ) -> PremiumServices {
        guard usesRealBilling else {
            let mock = MockPremiumEntitlementSource(defaults: defaults, detector: detector)
            return PremiumServices(
                gate: PremiumGate(source: mock),
                store: UnavailablePremiumStore(),
                purchaseAvailability: .comingSoon,
                testControls: mock
            )
        }

        let storeKit = makeStoreKitSource()
        #if DEBUG
        // The QA override only exists in DEBUG builds, so a release binary with real billing has
        // exactly one possible answer to "is this user premium": StoreKit's.
        let source = DebugPremiumOverrideSource(wrapping: storeKit, defaults: defaults)
        let testControls: TestPremiumControlling? = source
        #else
        let source = storeKit
        let testControls: TestPremiumControlling? = nil
        #endif
        return PremiumServices(
            gate: PremiumGate(source: source),
            // Shares the gate's source on purpose — a second one would mean a second
            // `Transaction.updates` listener and a second cache disagreeing with the first.
            store: makeStoreKitStore(source),
            purchaseAvailability: .store,
            testControls: testControls
        )
    }
}
