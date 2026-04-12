import SwiftUI
import FirebaseCore
import GoogleMobileAds

@main
struct QuoteAnimeApp: App {
    @StateObject private var dependencies: AppDependencies
    @StateObject private var router: AppRouter

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
        }
    }
}
