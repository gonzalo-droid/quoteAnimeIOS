import Foundation
import Combine
@testable import quoteAnime

/// Entitlement the test drives by hand. Exists so the gates, the habit limit and the paywall can
/// be tested without linking StoreKit — which, in a unit test, can neither be signed into nor be
/// handed a `Transaction`.
final class FakeEntitlementSource: PremiumEntitlementSource {
    private let subject: CurrentValueSubject<Bool, Never>
    private(set) var refreshCount = 0

    init(isPremium: Bool = false) {
        subject = CurrentValueSubject(isPremium)
    }

    var isPremium: Bool { subject.value }

    var isPremiumPublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }

    func refresh() async {
        refreshCount += 1
    }

    /// Simulates the store changing its mind — a renewal, a refund, a cancellation.
    func set(_ value: Bool) {
        subject.send(value)
    }
}

extension PremiumGate {
    /// A gate whose entitlement the test owns. Replaces the old `PremiumGate(defaults:)`, which
    /// needed a throwaway `UserDefaults` suite per test to avoid racing on the real user's flag.
    static func fake(premium: Bool = false) -> PremiumGate {
        PremiumGate(source: FakeEntitlementSource(isPremium: premium))
    }
}
