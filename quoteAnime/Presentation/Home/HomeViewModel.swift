import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var quotes: [Quote] = []
    @Published var isLoading = true
    @Published var loadError: String? = nil
    @Published var currentIndex: Int = 0
    @Published var showShareSheet = false
    @Published var shareImage: UIImage? = nil

    private var getAllQuotes: GetAllQuotesUseCase?
    private var toggleFavoriteUseCase: ToggleFavoriteUseCase?
    private var getUserPreferences: GetUserPreferencesUseCase?
    private var rescheduleNotifications: RescheduleQuoteNotificationsUseCase?
    private var router: AppRouter?
    private var setupDone = false

    /// Anime selection the currently loaded feed was built from, so returning from Settings
    /// can tell whether the feed is stale without refetching every time.
    private var appliedCategoryIds: Set<String>?

    // MARK: - Setup

    func setup(
        getAllQuotes: GetAllQuotesUseCase,
        toggleFavorite: ToggleFavoriteUseCase,
        getUserPreferences: GetUserPreferencesUseCase,
        rescheduleNotifications: RescheduleQuoteNotificationsUseCase,
        router: AppRouter
    ) {
        guard !setupDone else { return }
        setupDone = true
        self.getAllQuotes           = getAllQuotes
        self.toggleFavoriteUseCase = toggleFavorite
        self.getUserPreferences    = getUserPreferences
        self.rescheduleNotifications = rescheduleNotifications
        self.router                = router
        Task { await loadQuotes() }
    }

    // MARK: - Data

    func loadQuotes() async {
        isLoading = true
        loadError = nil
        let prefs = getUserPreferences?.execute() ?? UserPreferences()
        do {
            let fetched = try await getAllQuotes?.execute(filteredBy: prefs.selectedCategoryIds) ?? []
            quotes       = fetched.shuffled()
            currentIndex = 0
            appliedCategoryIds = prefs.selectedCategoryIds
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false

        // Refill notification budget on every app launch
        // (iOS allows max 64 pending notifications; with high frequency they drain in days).
        // Reuses the feed we just loaded instead of hitting the network a second time.
        guard !quotes.isEmpty else { return }
        await rescheduleNotifications?.execute(preferences: prefs, pool: quotes)
    }

    /// Called when Home comes back to the front. The anime selection lives in Settings and is
    /// written straight to the store, so the feed has to notice it changed while we were away.
    func reloadIfCategorySelectionChanged() async {
        guard setupDone, let prefs = getUserPreferences?.execute() else { return }
        guard prefs.selectedCategoryIds != appliedCategoryIds else { return }
        await loadQuotes()
    }

    // MARK: - Favorites

    func toggleFavorite(at index: Int) async {
        guard index < quotes.count else { return }
        do {
            try await toggleFavoriteUseCase?.execute(quotes[index])
            quotes[index].isFavorite.toggle()
        } catch {
            print("[HomeViewModel] toggleFavorite error: \(error)")
        }
    }

    // MARK: - Share

    func buildShareImage() {
        guard currentIndex < quotes.count else { return }
        let quote = quotes[currentIndex]
        Task {
            shareImage = await ShareImageRenderer.fetchAndRender(quote: quote)
            if shareImage != nil { showShareSheet = true }
        }
    }

    // MARK: - Navigation

    func openCatalog() {
        router?.push(.catalog)
    }

    func openSettings() {
        router?.push(.settings)
    }

    // MARK: - Helpers

    static let gradients: [(Color, Color)] = [
        (Color(hex: "#0C0C1E"), Color(hex: "#1A1040")),
        (Color(hex: "#0C0C1E"), Color(hex: "#0D2137")),
        (Color(hex: "#0C0C1E"), Color(hex: "#1A0D2E")),
        (Color(hex: "#0C0C1E"), Color(hex: "#0D1A37")),
        (Color(hex: "#1A0C1E"), Color(hex: "#2D1040")),
    ]

    func gradient(for index: Int) -> LinearGradient {
        let pair = Self.gradients[index % Self.gradients.count]
        return LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
