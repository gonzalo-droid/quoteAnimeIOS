import SwiftUI
import Combine

/// What the paywall says to the user after an attempt. Mirrors Android's `PaywallMessage`, plus
/// the two restore outcomes (Android has no restore action) and `unverified` (Android never
/// verifies anything, so it has nothing to report).
///
/// The store's own error text never reaches the UI: it is English, internal and written for
/// developers — same call Android makes with Play's `debugMessage`.
enum PaywallMessage: Equatable {
    case purchasePending
    case purchaseCancelled
    case purchaseUnverified
    case network
    case storeUnavailable
    case purchaseFailed
    case restored
    case nothingToRestore

    var text: String {
        switch self {
        case .purchasePending:
            return String(localized: "Tu compra está pendiente — vamos a desbloquear premium apenas se complete.")
        case .purchaseCancelled:
            return String(localized: "Compra cancelada.")
        case .purchaseUnverified:
            return String(localized: "No pudimos verificar la compra con la App Store.")
        case .network:
            return String(localized: "Sin conexión. Revisa tu red e intenta de nuevo.")
        case .storeUnavailable:
            return String(localized: "La App Store no está disponible ahora. Inténtalo más tarde.")
        case .purchaseFailed:
            return String(localized: "Algo salió mal con la compra. Prueba de nuevo.")
        case .restored:
            return String(localized: "Listo, restauramos tu suscripción.")
        case .nothingToRestore:
            return String(localized: "No encontramos compras para restaurar.")
        }
    }

    static func forError(_ reason: PremiumErrorReason) -> PaywallMessage {
        switch reason {
        case .network:          return .network
        case .storeUnavailable: return .storeUnavailable
        case .unverified:       return .purchaseUnverified
        case .unknown:          return .purchaseFailed
        }
    }
}

struct PaywallUiState {
    var purchaseAvailability: PremiumPurchaseAvailability = .store
    var isPremium: Bool = false
    var isLoadingOffers: Bool = true
    var offers: [SubscriptionOffer] = []
    var selectedOfferId: String?
    var isPurchasing: Bool = false
    var isRestoring: Bool = false
    var message: PaywallMessage?
    /// The "(solo pruebas)" switch: DEBUG and TestFlight builds only, never the App Store.
    var canUseTestPremium: Bool = false

    /// Premium is not on sale yet (`PremiumConfig.usesRealBilling == false`): the benefits are
    /// shown and the button says "Próximamente", disabled.
    var isComingSoon: Bool { purchaseAvailability == .comingSoon }

    /// The elegant empty state Android has: plans were asked for and none came back.
    var offersUnavailable: Bool { !isComingSoon && !isLoadingOffers && offers.isEmpty }

    var selectedOffer: SubscriptionOffer? {
        offers.first { $0.id == selectedOfferId } ?? offers.first
    }

    var canSubscribe: Bool { !isComingSoon && selectedOffer != nil && !isPurchasing && !isRestoring }

    /// Nothing was ever sold, so there is nothing to restore.
    var showsRestore: Bool { !isComingSoon }

    /// Nothing was ever sold, so there is no subscription to manage — a test-premium user sees
    /// "ya eres premium" and the switch to turn it off instead.
    var showsManageSubscription: Bool { !isComingSoon }
}

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var uiState = PaywallUiState()
    /// Drives the retention sheet, the iOS answer to Android's `CancelSubscriptionSheet`.
    @Published var isShowingCancelSheet = false

    private let premiumGate: PremiumGate
    private let store: PremiumStore
    private let testControls: TestPremiumControlling?
    private var cancellables = Set<AnyCancellable>()
    private var didLoadOffers = false

    init(
        premiumGate: PremiumGate,
        store: PremiumStore,
        purchaseAvailability: PremiumPurchaseAvailability = .store,
        testControls: TestPremiumControlling? = nil
    ) {
        self.premiumGate = premiumGate
        self.store = store
        self.testControls = testControls
        uiState.purchaseAvailability = purchaseAvailability
        uiState.isLoadingOffers = purchaseAvailability == .store
        uiState.isPremium = premiumGate.isPremium
        uiState.canUseTestPremium = testControls?.isTestPremiumAvailable ?? false
        // The entitlement can change while this screen is open — the purchase itself, obviously,
        // but also a cancellation made in Settings and picked up by `Transaction.updates`.
        premiumGate.isPremiumPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isPremium in
                self?.uiState.isPremium = isPremium
            }
            .store(in: &cancellables)
        // A release build starts out assuming "App Store" and may learn it is TestFlight a
        // moment later, once `AppTransaction` answers.
        testControls?.isTestPremiumAvailablePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isAvailable in
                self?.uiState.canUseTestPremium = isAvailable
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        uiState.isPremium = premiumGate.isPremium
        // "Próximamente" never asks the store for plans: with real billing off the app does not
        // talk to the App Store at all.
        guard !uiState.isComingSoon, !didLoadOffers else { return }
        didLoadOffers = true
        Task { await loadOffers() }
    }

    func loadOffers() async {
        guard !uiState.isComingSoon else { return }
        uiState.isLoadingOffers = true
        let offers = await store.loadOffers()
        uiState.offers = offers
        uiState.selectedOfferId = offers.first?.id
        uiState.isLoadingOffers = false
    }

    func retryLoadingOffers() {
        Task { await loadOffers() }
    }

    func selectOffer(_ offer: SubscriptionOffer) {
        uiState.selectedOfferId = offer.id
    }

    func subscribe() async {
        guard uiState.canSubscribe, let offer = uiState.selectedOffer else { return }
        uiState.isPurchasing = true
        let outcome = await store.purchase(offer)
        uiState.isPurchasing = false
        switch outcome {
        case .success:
            // No message on success, same as Android: the screen flipping to "ya eres premium"
            // is the feedback. Read the gate straight away instead of waiting for the publisher's
            // hop to the main run loop — the user tapped, the screen has to answer now.
            uiState.message = nil
            clearDebugOverrideAfterPurchase()
            uiState.isPremium = premiumGate.isPremium
        case .pending:
            uiState.message = .purchasePending
        case .cancelled:
            uiState.message = .purchaseCancelled
        case .failed(let reason):
            uiState.message = .forError(reason)
        }
    }

    func restorePurchases() async {
        guard uiState.showsRestore, !uiState.isRestoring else { return }
        uiState.isRestoring = true
        let outcome = await store.restore()
        uiState.isRestoring = false
        switch outcome {
        case .restored:
            uiState.message = .restored
            clearDebugOverrideAfterPurchase()
            uiState.isPremium = premiumGate.isPremium
        case .nothingToRestore:
            uiState.message = .nothingToRestore
        case .failed(let reason):
            uiState.message = .forError(reason)
        }
    }

    func onManageSubscriptionTapped() {
        guard uiState.showsManageSubscription else { return }
        isShowingCancelSheet = true
    }

    func onKeepPremium() {
        isShowingCancelSheet = false
    }

    func onCancelAnyway() {
        isShowingCancelSheet = false
        Task { await ManageSubscription.open() }
    }

    func onMessageShown() {
        uiState.message = nil
    }

    // MARK: - Test premium

    /// The "(solo pruebas)" buttons. Does nothing in an App Store build, where the switch is
    /// neither shown nor honoured.
    func setTestPremium(_ enabled: Bool) {
        guard uiState.canUseTestPremium, let testControls else { return }
        testControls.setTestPremium(enabled)
        uiState.isPremium = premiumGate.isPremium
    }

    /// A real purchase must win over a QA override — otherwise a tester who forced premium off
    /// buys the subscription and still sees the free app.
    private func clearDebugOverrideAfterPurchase() {
        #if DEBUG
        (premiumGate.source as? DebugPremiumOverrideSource)?.clearOverride()
        #endif
    }
}
