import SwiftUI
import Combine

enum AppScreen: Equatable {
    case splash
    case onboarding
    case main
}

enum AppRoute: Hashable {
    case catalog
    case settings
    case widgetTutorial
    case routine
    case habitEditor(habitId: String?)
    case paywall
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    @Published var navigationPath = NavigationPath()

    func navigateToOnboarding() { currentScreen = .onboarding }
    func navigateToMain()       { currentScreen = .main }

    func push(_ route: AppRoute) {
        navigationPath.append(route)
    }

    func popToRoot() {
        navigationPath = NavigationPath()
    }
}
