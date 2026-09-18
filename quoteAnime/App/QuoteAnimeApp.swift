import SwiftUI
import FirebaseCore
import GoogleMobileAds

@main
struct QuoteAnimeApp: App {
    @StateObject private var dependencies: AppDependencies
    @StateObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()
        MobileAds.shared.start()
        // Warm up the interstitial so the first ad is ready when the user shares
        _ = ShareInterstitialManager.shared
        // Built here, not lazily by `StateObject`: `AppDependencies` installs the notification
        // delegate, and a reminder tap that cold-launches the app is only delivered to a delegate
        // that exists before launch finishes.
        let dependencies = AppDependencies()
        let router = AppRouter(isRoutineAvailable: dependencies.isRoutineAvailable)
        dependencies.routeNotificationTaps { [weak router] link in router?.open(link) }
        _dependencies = StateObject(wrappedValue: dependencies)
        _router       = StateObject(wrappedValue: router)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(dependencies)
                .environmentObject(router)
                .preferredColorScheme(.dark)
                // The routine widgets' `widgetURL` — same door as a tapped reminder.
                .onOpenURL { url in
                    guard let link = AppDeepLink(url: url) else { return }
                    router.open(link)
                }
                // Android re-syncs the entitlement on every process start, and its billing
                // repository asks for a re-sync on every return to the foreground too (which its
                // own code never wires up). iOS does both: a subscription cancelled or refunded
                // in Settings has to be noticed without a cold launch. While
                // `PremiumConfig.usesRealBilling` is false the same call never reaches StoreKit's
                // entitlements — it only settles whether this release build is TestFlight.
                .task { await dependencies.premiumGate.refresh() }
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase == .active else { return }
                    Task { await dependencies.premiumGate.refresh() }
                }
        }
    }
}
