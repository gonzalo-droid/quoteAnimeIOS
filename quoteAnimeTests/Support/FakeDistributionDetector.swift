import Foundation
@testable import quoteAnime

/// Where the app "runs", decided by the test — so debug, TestFlight and App Store can all be
/// exercised from a test bundle that was compiled in exactly one configuration.
final class FakeDistributionDetector: AppDistributionDetecting {
    let provisional: AppDistribution
    /// What `detect()` answers; `nil` simulates "could not ask yet" (offline, the lookup threw).
    var detected: AppDistribution?
    /// Makes `detect()` take a while, so two refreshes can overlap.
    var delayNanoseconds: UInt64 = 0
    private(set) var detectCount = 0

    init(provisional: AppDistribution = .appStore, detected: AppDistribution? = nil) {
        self.provisional = provisional
        self.detected = detected
    }

    /// A build whose environment is already known before anyone asks.
    static func known(_ distribution: AppDistribution) -> FakeDistributionDetector {
        FakeDistributionDetector(provisional: distribution, detected: distribution)
    }

    func detect() async -> AppDistribution? {
        detectCount += 1
        if delayNanoseconds > 0 { try? await Task.sleep(nanoseconds: delayNanoseconds) }
        return detected
    }
}

/// A throwaway `UserDefaults` suite, so a test never reads or writes the real user's flag.
struct TestDefaults {
    let defaults: UserDefaults
    let suiteName: String

    init(premiumFlag: Bool? = nil) {
        suiteName = "test.premium.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        if let premiumFlag {
            defaults.set(premiumFlag, forKey: MockPremiumEntitlementSource.flagKey)
        }
    }

    func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
}
