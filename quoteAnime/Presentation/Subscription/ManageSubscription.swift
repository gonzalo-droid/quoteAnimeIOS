import UIKit
import StoreKit

/// Where the user goes to change or cancel the subscription.
///
/// Android deep-links to Play's subscription centre
/// (`play.google.com/store/account/subscriptions?sku=…&package=…`). The App Store equivalent is a
/// sheet the system presents over the app; the URL below is only the fallback for when there is
/// no scene to present it in, or when the sheet refuses (it does nothing against a local
/// `.storekit` configuration, for instance).
enum ManageSubscription {
    static let fallbackURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    @discardableResult
    @MainActor
    static func open() async -> Bool {
        guard let scene = activeWindowScene() else {
            return await openFallback()
        }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
            return true
        } catch {
            print("[ManageSubscription] showManageSubscriptions failed: \(error)")
            return await openFallback()
        }
    }

    @MainActor
    private static func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }

    @MainActor
    private static func openFallback() async -> Bool {
        await UIApplication.shared.open(fallbackURL)
    }
}
