import Foundation
import StoreKit

/// Tells a TestFlight install from an App Store one. `AppTransaction.shared` (iOS 16+) is the
/// authority — signed by the App Store, environment explicit — so only a *verified* `.sandbox`
/// counts as TestFlight.
///
/// But it is asked **only when the receipt path already says sandbox**. Measured on the iOS 26
/// simulator with a Release build: with no app transaction on the device, `AppTransaction.shared`
/// makes storekitd request one from the App Store with an *interactive* authentication ("Receipt
/// renewal"), and the user gets a "Sign in to Apple Account" alert at launch. A real customer can
/// be in that state too (a device restored from a backup can lack its receipt), and billing is
/// supposed to be asleep. `Bundle.main.appStoreReceiptURL` is deprecated as a *receipt*, but its
/// file name is still set by the install environment (`sandboxReceipt` for TestFlight and
/// sandbox, `receipt` for the App Store) and reading it touches nothing: an App Store build
/// decides `.appStore` without ever talking to the store.
///
/// Known blind spot: App Review also runs the build against the sandbox, so a reviewer would be
/// told "TestFlight" too. See `PARITY.md` before submitting with `usesRealBilling == false`.
struct AppTransactionDistributionDetector: AppDistributionDetecting {
    /// Local, synchronous, no network. `false` means "certainly not TestFlight".
    static func mayBeTestFlight(receiptURL: URL?) -> Bool {
        receiptURL?.lastPathComponent == "sandboxReceipt"
    }

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
        guard Self.mayBeTestFlight(receiptURL: Bundle.main.appStoreReceiptURL) else {
            return .appStore
        }
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
