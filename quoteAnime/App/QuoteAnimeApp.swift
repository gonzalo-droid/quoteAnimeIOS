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
        _dependencies = StateObject(wrappedValue: AppDependencies())
        _router       = StateObject(wrappedValue: AppRouter())
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(dependencies)
                .environmentObject(router)
                .preferredColorScheme(.dark)
                // Android re-syncs the entitlement on every process start, and its billing
                // repository asks for a re-sync on every return to the foreground too (which its
                // own code never wires up). iOS does both: a subscription cancelled or refunded
                // in Settings has to be noticed without a cold launch.
                .task { await dependencies.premiumGate.refresh() }
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase == .active else { return }
                    Task { await dependencies.premiumGate.refresh() }
                }
        }
    }
}
