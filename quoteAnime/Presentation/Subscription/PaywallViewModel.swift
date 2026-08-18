import SwiftUI
import Combine

struct PaywallUiState {
    var isPremium: Bool = false
}

/// Pre-billing mock, mirrors Android's first Premium phase: "Suscribirme" just flips the
/// local `PremiumGate` flag. When StoreKit lands, only `onSubscribe()`'s body changes —
/// every reader of `PremiumGate.isPremium` stays the same.
@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var uiState = PaywallUiState()

    private let premiumGate: PremiumGate

    init(premiumGate: PremiumGate) {
        self.premiumGate = premiumGate
        uiState.isPremium = premiumGate.isPremium
    }

    func onAppear() {
        uiState.isPremium = premiumGate.isPremium
    }

    func onSubscribe() {
        premiumGate.isPremium = true
        uiState.isPremium = true
    }

    /// QA-only affordance to flip back off, since there is no real subscription to cancel yet.
    func onRemovePremiumForTesting() {
        premiumGate.isPremium = false
        uiState.isPremium = false
    }
}
