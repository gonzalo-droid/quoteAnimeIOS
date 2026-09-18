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
    var isPremium: Bool = false
    var isLoadingOffers: Bool = true
    var offers: [SubscriptionOffer] = []
    var selectedOfferId: String?
    var isPurchasing: Bool = false
    var isRestoring: Bool = false
    var message: PaywallMessage?

    /// The elegant empty state Android has: plans were asked for and none came back.
    var offersUnavailable: Bool { !isLoadingOffers && offers.isEmpty }

    var selectedOffer: SubscriptionOffer? {
        offers.first { $0.id == selectedOfferId } ?? offers.first
    }

    var canSubscribe: Bool { selectedOffer != nil && !isPurchasing && !isRestoring }
}

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var uiState = PaywallUiState()
    /// Drives the retention sheet, the iOS answer to Android's `CancelSubscriptionSheet`.
    @Published var isShowingCancelSheet = false

    private let premiumGate: PremiumGate
    private let store: PremiumStore
    private var cancellable: AnyCancellable?
    private var didLoadOffers = false

    init(premiumGate: PremiumGate, store: PremiumStore) {
        self.premiumGate = premiumGate
        self.store = store
        uiState.isPremium = premiumGate.isPremium
        // The entitlement can change while this screen is open — the purchase itself, obviously,
        // but also a cancellation made in Settings and picked up by `Transaction.updates`.
        cancellable = premiumGate.isPremiumPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isPremium in
                self?.uiState.isPremium = isPremium
            }
    }

    func onAppear() {
        uiState.isPremium = premiumGate.isPremium
        guard !didLoadOffers else { return }
        didLoadOffers = true
        Task { await loadOffers() }
    }

    func loadOffers() async {
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

    func subscribe() {
        guard let offer = uiState.selectedOffer, !uiState.isPurchasing else { return }
        uiState.isPurchasing = true
        Task {
            let outcome = await store.purchase(offer)
            uiState.isPurchasing = false
            switch outcome {
            case .success:
                // No message on success, same as Android: the screen flipping to "ya eres
                // premium" is the feedback.
                uiState.message = nil
                clearDebugOverrideAfterPurchase()
            case .pending:
                uiState.message = .purchasePending
            case .cancelled:
                uiState.message = .purchaseCancelled
            case .failed(let reason):
                uiState.message = .forError(reason)
            }
        }
    }

    func restorePurchases() {
        guard !uiState.isRestoring else { return }
        uiState.isRestoring = true
        Task {
            let outcome = await store.restore()
            uiState.isRestoring = false
            switch outcome {
            case .restored:
                uiState.message = .restored
                clearDebugOverrideAfterPurchase()
            case .nothingToRestore:
                uiState.message = .nothingToRestore
            case .failed(let reason):
                uiState.message = .forError(reason)
            }
        }
    }

    func onManageSubscriptionTapped() {
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

    // MARK: - QA only

    #if DEBUG
    /// The pre-billing mock, now an explicit override instead of a write to the same flag the
    /// store owns. Absent from release builds.
    func debugSetPremium(_ value: Bool) {
        (premiumGate.source as? DebugPremiumOverrideSource)?.setOverride(value)
    }

    func debugFollowStore() {
        (premiumGate.source as? DebugPremiumOverrideSource)?.clearOverride()
    }
    #endif

    /// A real purchase must win over a QA override — otherwise a tester who forced premium off
    /// buys the subscription and still sees the free app.
    private func clearDebugOverrideAfterPurchase() {
        #if DEBUG
        debugFollowStore()
        #endif
    }
}
