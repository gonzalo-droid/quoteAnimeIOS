import SwiftUI
import FirebaseCore

@main
struct QuoteAnimeApp: App {
    @StateObject private var dependencies: AppDependencies
    @StateObject private var router: AppRouter

    init() {
        FirebaseApp.configure()
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
