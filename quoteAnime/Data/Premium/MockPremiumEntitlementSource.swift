import Foundation
import Combine

/// Premium while `PremiumConfig.usesRealBilling` is `false`: no store at all, just a local flag
/// that only DEBUG and TestFlight builds may turn on.
///
/// In an App Store build `isPremium` is `false` **whatever the flag says**. That matters because
/// the flag's key has history: before StoreKit, the mock paywall's "Suscribirme" set it for
/// anyone who tapped, so real users can carry a `true` in it. The key is reused on purpose — in
/// DEBUG it is also the StoreKit build's QA override (`DebugPremiumOverrideSource`), so a tester's
/// state means the same thing in both modes — and made harmless by the distribution check rather
/// than by a fresh key.
///
/// Never talks to the store. The only StoreKit call anywhere near it is the detector's
/// `AppTransaction.shared`, which is how a release build learns it is TestFlight.
final class MockPremiumEntitlementSource: PremiumEntitlementSource, TestPremiumControlling {
    static let flagKey = "pref_is_premium"

    private let defaults: UserDefaults
    private let detector: AppDistributionDetecting
    private let distributionSubject: CurrentValueSubject<AppDistribution, Never>
    private let premiumSubject: CurrentValueSubject<Bool, Never>
    private var isDistributionResolved = false

    init(defaults: UserDefaults = .standard, detector: AppDistributionDetecting) {
        self.defaults = defaults
        self.detector = detector
        let distribution = detector.provisional
        distributionSubject = CurrentValueSubject(distribution)
        premiumSubject = CurrentValueSubject(
            Self.isPremium(flag: defaults.bool(forKey: Self.flagKey), distribution: distribution)
        )
    }

    var distribution: AppDistribution { distributionSubject.value }

    // MARK: - PremiumEntitlementSource

    var isPremium: Bool { premiumSubject.value }

    var isPremiumPublisher: AnyPublisher<Bool, Never> { premiumSubject.eraseToAnyPublisher() }

    /// Called at launch and on every return to the foreground, like the StoreKit source. Here it
    /// only finishes working out where the app runs — once that is known it is never asked again.
    func refresh() async {
        guard !isDistributionResolved else { return }
        guard let resolved = await detector.detect() else { return }
        isDistributionResolved = true
        if distributionSubject.value != resolved {
            distributionSubject.send(resolved)
        }
        recompute()
    }

    // MARK: - TestPremiumControlling

    var isTestPremiumAvailable: Bool { distribution.allowsTestPremium }

    var isTestPremiumAvailablePublisher: AnyPublisher<Bool, Never> {
        distributionSubject.map(\.allowsTestPremium).removeDuplicates().eraseToAnyPublisher()
    }

    func setTestPremium(_ enabled: Bool) {
        guard isTestPremiumAvailable else { return }
        defaults.set(enabled, forKey: Self.flagKey)
        recompute()
    }

    // MARK: - Internals

    static func isPremium(flag: Bool, distribution: AppDistribution) -> Bool {
        flag && distribution.allowsTestPremium
    }

    private func recompute() {
        let newValue = Self.isPremium(flag: defaults.bool(forKey: Self.flagKey), distribution: distribution)
        guard premiumSubject.value != newValue else { return }
        premiumSubject.send(newValue)
    }
}
