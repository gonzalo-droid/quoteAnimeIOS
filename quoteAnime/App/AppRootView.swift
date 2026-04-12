import SwiftUI

/// Root view that switches between Splash, Onboarding, and Main based on AppRouter state.
struct AppRootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var deps: AppDependencies

    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()

            switch router.currentScreen {
            case .splash:
                SplashView(
                    isOnboardingCompleted: deps.getOnboardingCompletedUseCase.execute(),
                    onComplete: { isFirstTime in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            if isFirstTime {
                                router.navigateToOnboarding()
                            } else {
                                router.navigateToMain()
                            }
                        }
                    }
                )
                .transition(.opacity)

            case .onboarding:
                OnboardingContainerView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))

            case .main:
                MainContainerView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: router.currentScreen)
    }
}

// MARK: - Onboarding Container

struct OnboardingContainerView: View {
    @EnvironmentObject private var deps: AppDependencies
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        OnboardingView(viewModel: viewModel)
            .task {
                viewModel.setup(
                    getCategoriesUseCase: deps.getCategoriesUseCase,
                    setOnboardingCompleted: deps.setOnboardingCompletedUseCase,
                    updateUserPreferences: deps.updateUserPreferencesUseCase,
                    getUserPreferences: deps.getUserPreferencesUseCase,
                    onComplete: { router.navigateToMain() }
                )
            }
    }
}

// MARK: - Main Container (NavigationStack)

struct MainContainerView: View {
    @EnvironmentObject private var deps: AppDependencies
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.navigationPath) {
            HomeContainerView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .catalog:
            CatalogView(
                getAllQuotesUseCase: deps.getAllQuotesUseCase,
                getFavoriteQuotesUseCase: deps.getFavoriteQuotesUseCase,
                toggleFavoriteUseCase: deps.toggleFavoriteUseCase
            )

        case .settings:
            SettingsView(
                getUserPreferences: deps.getUserPreferencesUseCase,
                updateUserPreferences: deps.updateUserPreferencesUseCase,
                notificationScheduler: deps.notificationScheduler,
                getRandomQuote: deps.getRandomQuoteUseCase
            )

        case .widgetTutorial:
            WidgetTutorialView()
        }
    }
}
