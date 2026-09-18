import Foundation
import StoreKit

/// Tells a TestFlight install from an App Store one through `AppTransaction.shared` (iOS 16+).
///
/// `Bundle.main.appStoreReceiptURL` ending in `sandboxReceipt` was the old trick; it is deprecated
/// along with the receipt itself, and a file name is not a signature. `AppTransaction` is signed
/// by the App Store and carries its environment explicitly, so only a *verified* `.sandbox`
/// counts as TestFlight.
///
/// Known blind spot: App Review also runs the build against the sandbox, so a reviewer would be
/// told "TestFlight" too. See `PARITY.md` before submitting with `usesRealBilling == false`.
struct AppTransactionDistributionDetector: AppDistributionDetecting {
    var provisional: AppDistribution {
        #if DEBUG
        return .debug
        #else
        return .appStore
        #endif
    }

    func detect() async -> AppDistribution? {
        #if DEBUG
        // Nothing to ask: a DEBUG build never reaches a customer.
        return .debug
        #else
        do {
            switch try await AppTransaction.shared {
            case .verified(let transaction):
                return AppDistribution.resolve(
                    isDebugBuild: false,
                    environment: StoreEnvironment(transaction.environment),
                    isVerified: true
                )
            case .unverified(let transaction, let error):
                print("[AppTransactionDistributionDetector] unverified app transaction: \(error)")
                return AppDistribution.resolve(
                    isDebugBuild: false,
                    environment: StoreEnvironment(transaction.environment),
                    isVerified: false
                )
            }
        } catch {
            print("[AppTransactionDistributionDetector] app transaction unavailable: \(error)")
            return nil
        }
        #endif
    }
}

private extension StoreEnvironment {
    init(_ environment: AppStore.Environment) {
        switch environment {
        case .production: self = .production
        case .sandbox:    self = .sandbox
        case .xcode:      self = .xcode
        default:          self = .other
        }
    }
}
