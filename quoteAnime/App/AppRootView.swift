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
                getAllQuotes: deps.getAllQuotesUseCase,
                premiumGate: deps.premiumGate
            )

        case .widgetTutorial:
            WidgetTutorialView()

        case .routine:
            if let getActiveHabits = deps.getActiveHabitsUseCase,
               let getArchivedHabits = deps.getArchivedHabitsUseCase,
               let getGlobalStreak = deps.getGlobalStreakUseCase,
               let toggleCompletion = deps.toggleHabitCompletionUseCase,
               let archiveHabit = deps.archiveHabitUseCase,
               let unarchiveHabit = deps.unarchiveHabitUseCase,
               let deleteHabit = deps.deleteHabitUseCase {
                RoutineView(
                    getActiveHabitsUseCase: getActiveHabits,
                    getArchivedHabitsUseCase: getArchivedHabits,
                    getGlobalStreakUseCase: getGlobalStreak,
                    toggleHabitCompletionUseCase: toggleCompletion,
                    archiveHabitUseCase: archiveHabit,
                    unarchiveHabitUseCase: unarchiveHabit,
                    deleteHabitUseCase: deleteHabit,
                    premiumGate: deps.premiumGate
                )
            } else {
                unavailableView(message: "Mi Rutina requiere iOS 17 o superior")
            }

        case .habitEditor(let habitId):
            if let habitRepository = deps.habitRepository,
               let createHabit = deps.createHabitUseCase,
               let updateHabit = deps.updateHabitUseCase {
                HabitEditorView(
                    habitId: habitId,
                    createHabitUseCase: createHabit,
                    updateHabitUseCase: updateHabit,
                    habitRepository: habitRepository,
                    premiumGate: deps.premiumGate
                )
            } else {
                unavailableView(message: "Mi Rutina requiere iOS 17 o superior")
            }

        case .paywall:
            PaywallView(premiumGate: deps.premiumGate)
        }
    }

    private func unavailableView(message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDark.ignoresSafeArea())
    }
}
