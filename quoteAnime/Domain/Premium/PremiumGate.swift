import Foundation
import Combine

/// Single place plan-based limits live, and the only type the rest of the app talks to about
/// premium. Where `isPremium` comes from is behind `PremiumEntitlementSource`, chosen once by
/// `PremiumConfig.usesRealBilling`: the local mock (`MockPremiumEntitlementSource`) while it is
/// `false`, StoreKit — wrapped by a QA override in DEBUG builds — once it is `true`.
///
/// `isPremium` still *proxies* straight to the source rather than caching a copy — there is no
/// in-memory state to go stale across the app's several independent view models, so it is safe to
/// hold multiple instances (or use `.shared` from non-DI contexts like `ShareInterstitialManager`)
/// without them ever disagreeing. What `ObservableObject` adds is only the redraw: a SwiftUI view
/// that reads `isPremium` in its body and holds the gate as `@ObservedObject` re-renders the
/// moment StoreKit changes its mind, which a plain `UserDefaults` read never did.
final class PremiumGate: ObservableObject {
    static let shared = PremiumServices.live.gate
    static let freeHabitLimit = 3

    /// Exposed for the paywall's DEBUG path only: a real purchase clears the QA override on
    /// *this* source (`DebugPremiumOverrideSource`).
    let source: PremiumEntitlementSource
    /// `PremiumConfig.paymentsEnabled` in the app. While `false` the free plan has no limits —
    /// there is no paywall to send anyone to — but `isPremium` stays the real entitlement, so ads
    /// keep following it. Defaults to `true` so tests exercise the paid plan unless they opt out.
    let paymentsEnabled: Bool
    private var cancellable: AnyCancellable?

    init(source: PremiumEntitlementSource, paymentsEnabled: Bool = true) {
        self.source = source
        self.paymentsEnabled = paymentsEnabled
        cancellable = source.isPremiumPublisher
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    var isPremium: Bool { source.isPremium }

    /// For the view models that need to react rather than redraw.
    var isPremiumPublisher: AnyPublisher<Bool, Never> { source.isPremiumPublisher }

    var maxActiveHabits: Int {
        unlocksPremiumFeatures ? Int.max : Self.freeHabitLimit
    }

    /// What the plan limits check (habit cap, padlocked suggestions) — never the ads, which read
    /// `isPremium`.
    var unlocksPremiumFeatures: Bool {
        isPremium || !paymentsEnabled
    }

    /// Called at launch and on every return to the foreground. With real billing it re-reads
    /// StoreKit; with the mock it only finishes working out whether this is a TestFlight build.
    func refresh() async {
        await source.refresh()
    }
}
