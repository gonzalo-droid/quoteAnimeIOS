import Foundation

/// Single place plan-based limits live. `isPremium` proxies straight to UserDefaults — no
/// in-memory state to go stale across the app's several independent view models — so it's
/// safe to hold multiple instances (or use `.shared` from non-DI contexts like
/// `ShareInterstitialManager`) without them ever disagreeing with each other.
///
/// Pre-billing: `PaywallViewModel` flips the flag directly from its "Suscribirme" button.
/// When StoreKit lands, only that call site changes — every reader here stays the same.
final class PremiumGate {
    static let shared = PremiumGate()
    static let freeHabitLimit = 3

    private let defaults = UserDefaults.standard
    private let key = "pref_is_premium"

    var isPremium: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }

    var maxActiveHabits: Int {
        isPremium ? Int.max : Self.freeHabitLimit
    }
}
