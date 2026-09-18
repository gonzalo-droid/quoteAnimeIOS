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
    case categorySelection
    case widgetTutorial
    case routine
    case habitDetail(habitId: String)
    case habitEditor(habitId: String?)
    case paywall
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    /// A typed path rather than a `NavigationPath`, so a deep link can see what is already on
    /// screen instead of stacking a second copy of it.
    @Published var navigationPath: [AppRoute] = []

    /// A deep link that arrived while there was no navigation stack to apply it to: a cold
    /// launch from a reminder or a widget (the tap lands before the splash has finished), or a
    /// tap during the onboarding. Applied by `navigateToMain()`, never by skipping ahead.
    private(set) var pendingDeepLink: AppDeepLink?

    /// A quote Home has been asked to scroll to (the quote widget's tap). Home consumes it with
    /// `consumeQuoteFocusRequest()`; published so a warm tap reaches a Home that is already on
    /// screen, and a cold one is picked up when Home first subscribes.
    @Published private(set) var quoteFocusRequest: String?

    /// False below iOS 17, where Mi Rutina does not exist: a link to it then only opens the app.
    private let isRoutineAvailable: Bool

    init(isRoutineAvailable: Bool = true) {
        self.isRoutineAvailable = isRoutineAvailable
    }

    func navigateToOnboarding() { currentScreen = .onboarding }

    func navigateToMain() {
        currentScreen = .main
        if let link = pendingDeepLink {
            pendingDeepLink = nil
            apply(link)
        }
    }

    func push(_ route: AppRoute) {
        navigationPath.append(route)
    }

    func popToRoot() {
        navigationPath = []
    }

    func consumeQuoteFocusRequest() {
        quoteFocusRequest = nil
    }

    /// The single entry point for every deep link — the reminder tap and the widgets' URL.
    ///
    /// Android (`e4fbf2f`) starts the graph at Mi Rutina on a cold launch, skipping the splash
    /// and the onboarding, and on a warm one navigates there popping everything else. iOS keeps
    /// the second half and not the first: the link waits for the splash — and for the onboarding
    /// if it isn't finished — and then replaces whatever was pushed with Mi Rutina alone, on top
    /// of Home so the back gesture has somewhere to go.
    ///
    /// A quote link (Android: `home?quoteId=` popping everything) waits the same way, then pops
    /// back to Home and asks it to scroll to the quote. It exists on every iOS version.
    func open(_ link: AppDeepLink) {
        switch link {
        case .routine:
            guard isRoutineAvailable else { return }
        case .quote:
            break
        }
        guard currentScreen == .main else {
            pendingDeepLink = link
            return
        }
        apply(link)
    }

    private func apply(_ link: AppDeepLink) {
        switch link {
        case .routine:
            // Already there (and nothing on top): leave the stack alone, no second push.
            guard navigationPath != [.routine] else { return }
            navigationPath = [.routine]
        case .quote(let id):
            if !navigationPath.isEmpty { navigationPath = [] }
            quoteFocusRequest = id
        }
    }
}
