import Foundation
import Combine

/// Single place plan-based limits live, and the only type the rest of the app talks to about
/// premium. Where `isPremium` comes from is behind `PremiumEntitlementSource`: StoreKit in every
/// build, wrapped by a QA override in DEBUG ones.
///
/// `isPremium` still *proxies* straight to the source rather than caching a copy — there is no
/// in-memory state to go stale across the app's several independent view models, so it is safe to
/// hold multiple instances (or use `.shared` from non-DI contexts like `ShareInterstitialManager`)
/// without them ever disagreeing. What `ObservableObject` adds is only the redraw: a SwiftUI view
/// that reads `isPremium` in its body and holds the gate as `@ObservedObject` re-renders the
/// moment StoreKit changes its mind, which a plain `UserDefaults` read never did.
final class PremiumGate: ObservableObject {
    static let shared = PremiumGate(source: PremiumGate.makeDefaultSource())
    static let freeHabitLimit = 3

    /// Exposed for the composition root only: `StoreKitPremiumStore` has to refresh *this* source
    /// after a purchase, and a second instance would mean a second cache and a second listener.
    let source: PremiumEntitlementSource
    private var cancellable: AnyCancellable?

    init(source: PremiumEntitlementSource) {
        self.source = source
        cancellable = source.isPremiumPublisher
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    var isPremium: Bool { source.isPremium }

    /// For the view models that need to react rather than redraw.
    var isPremiumPublisher: AnyPublisher<Bool, Never> { source.isPremiumPublisher }

    var maxActiveHabits: Int {
        isPremium ? Int.max : Self.freeHabitLimit
    }

    /// Re-reads the store. Called at launch and on every return to the foreground.
    func refresh() async {
        await source.refresh()
    }

    /// The QA override only exists in DEBUG builds, so a release binary has exactly one possible
    /// answer to "is this user premium": StoreKit's.
    private static func makeDefaultSource() -> PremiumEntitlementSource {
        let storeKit = StoreKitEntitlementSource()
        #if DEBUG
        return DebugPremiumOverrideSource(wrapping: storeKit)
        #else
        return storeKit
        #endif
    }
}
