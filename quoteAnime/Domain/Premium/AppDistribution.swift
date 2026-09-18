import Foundation
import Combine

/// Where this binary is running, at the granularity premium cares about: can a free "test
/// premium" switch be offered here, or could the person holding the phone be a real customer?
///
/// Only matters while `PremiumConfig.usesRealBilling` is `false`. With real billing on, StoreKit
/// answers for every environment and this is never consulted.
enum AppDistribution: Equatable {
    /// Built with the DEBUG configuration — Xcode, the simulator, a developer's phone.
    case debug
    /// A release binary installed from TestFlight.
    case testFlight
    /// A release binary that may have come from the App Store. Also the answer whenever the
    /// environment could not be proven to be anything else: failing closed means a TestFlight
    /// tester might miss the test switch, failing open would hand premium to every customer.
    case appStore

    /// Whether the mock that grants premium for free may be offered and honoured.
    var allowsTestPremium: Bool { self != .appStore }
}

/// The store environment a release binary reports, mapped at the edge so nothing below the data
/// layer links StoreKit (`AppStore.Environment` is a StoreKit type).
enum StoreEnvironment: Equatable {
    case production
    case sandbox
    case xcode
    /// A value this SDK does not know yet.
    case other
}

extension AppDistribution {
    /// The whole decision, pure so every combination can be pinned in a test regardless of the
    /// configuration the test target itself was compiled with.
    ///
    /// - A DEBUG build is `.debug` whatever the store says.
    /// - A release build is `.testFlight` **only** when a *verified* app transaction says
    ///   `.sandbox`. Everything else — production, an Xcode-signed transaction, an unverified one,
    ///   an environment this SDK does not know — is `.appStore`.
    /// - `nil` means "could not ask yet" (offline, the lookup threw): the caller keeps treating
    ///   the build as `.appStore` and may ask again later.
    static func resolve(
        isDebugBuild: Bool,
        environment: StoreEnvironment?,
        isVerified: Bool
    ) -> AppDistribution? {
        if isDebugBuild { return .debug }
        guard let environment else { return nil }
        guard isVerified else { return .appStore }
        return environment == .sandbox ? .testFlight : .appStore
    }
}

/// Finds out where the app is running. Injectable so the three cases can be tested without
/// depending on how the test bundle was compiled.
protocol AppDistributionDetecting {
    /// What is known before asking anyone: `.debug` in a DEBUG build, `.appStore` in a release
    /// one (fail closed until proven otherwise).
    var provisional: AppDistribution { get }

    /// The definitive answer, or `nil` when it cannot be known right now.
    func detect() async -> AppDistribution?
}

/// Premium without paying, for the builds that never reach a customer. Backs the "(solo pruebas)"
/// buttons on the paywall.
protocol TestPremiumControlling: AnyObject {
    /// `false` in an App Store build: the switch is neither shown nor honoured there.
    var isTestPremiumAvailable: Bool { get }

    /// Emits the current value on subscription and again on every change — a release build
    /// starts as "App Store" and may learn it is TestFlight a moment later.
    var isTestPremiumAvailablePublisher: AnyPublisher<Bool, Never> { get }

    /// Ignored where `isTestPremiumAvailable` is `false`.
    func setTestPremium(_ enabled: Bool)
}

/// What the paywall's main button can do in this build. Decided once, by
/// `PremiumConfig.usesRealBilling`.
enum PremiumPurchaseAvailability: Equatable {
    /// StoreKit: real plans, real purchase, restore and manage.
    case store
    /// The benefits are shown, the button says "Próximamente" and does nothing, and there is
    /// nothing to restore or manage.
    case comingSoon
}
