#if DEBUG
import Foundation
import Combine

/// The pre-billing mock, kept alive for QA and compiled **only into DEBUG builds** — a release
/// binary has exactly one possible answer to "is this user premium": StoreKit's.
///
/// It wraps the real source instead of replacing it: with no override set, everything behaves
/// exactly as it will in production. An override pins the answer until it is cleared, and a real
/// purchase clears it, so a tester who forced premium off and then bought something still sees
/// the purchase. Android's equivalent button does *not* do this — it writes `false` and the next
/// Play sync silently writes `true` back, which makes the affordance lie (reported as Android
/// debt).
final class DebugPremiumOverrideSource: PremiumEntitlementSource {
    /// The pre-billing flag's own key, reused on purpose so QA state set by the old mock still
    /// means something. Presence, not the value, is what marks an override as set.
    private static let overrideKey = "pref_is_premium"

    private let wrapped: PremiumEntitlementSource
    private let defaults: UserDefaults
    private let subject: CurrentValueSubject<Bool, Never>
    private var cancellable: AnyCancellable?

    init(wrapping wrapped: PremiumEntitlementSource, defaults: UserDefaults = .standard) {
        self.wrapped = wrapped
        self.defaults = defaults
        self.subject = CurrentValueSubject(
            Self.readOverride(defaults) ?? wrapped.isPremium
        )
        cancellable = wrapped.isPremiumPublisher.sink { [weak self] _ in
            self?.recompute()
        }
    }

    // MARK: - PremiumEntitlementSource

    var isPremium: Bool { subject.value }

    var isPremiumPublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }

    func refresh() async {
        await wrapped.refresh()
        recompute()
    }

    // MARK: - QA controls

    /// `nil` means "follow the store".
    var override: Bool? {
        Self.readOverride(defaults)
    }

    func setOverride(_ value: Bool) {
        defaults.set(value, forKey: Self.overrideKey)
        recompute()
    }

    func clearOverride() {
        defaults.removeObject(forKey: Self.overrideKey)
        recompute()
    }

    // MARK: - Internals

    private static func readOverride(_ defaults: UserDefaults) -> Bool? {
        guard defaults.object(forKey: overrideKey) != nil else { return nil }
        return defaults.bool(forKey: overrideKey)
    }

    private func recompute() {
        let newValue = Self.readOverride(defaults) ?? wrapped.isPremium
        guard subject.value != newValue else { return }
        subject.send(newValue)
    }
}
#endif
