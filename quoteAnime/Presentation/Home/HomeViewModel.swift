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
    private var getCategoriesUseCase: GetCategoriesUseCase?
    private var getUserPreferences: GetUserPreferencesUseCase?
    private var router: AppRouter?
    private var setupDone = false

    // MARK: - Setup

    func setup(
        getAllQuotes: GetAllQuotesUseCase,
        toggleFavorite: ToggleFavoriteUseCase,
        getCategoriesUseCase: GetCategoriesUseCase,
        getUserPreferences: GetUserPreferencesUseCase,
        router: AppRouter
    ) {
        guard !setupDone else { return }
        setupDone = true
        self.getAllQuotes          = getAllQuotes
        self.toggleFavoriteUseCase = toggleFavorite
        self.getCategoriesUseCase  = getCategoriesUseCase
        self.getUserPreferences    = getUserPreferences
        self.router                = router
        Task { await loadQuotes() }
    }

    // MARK: - Data

    func loadQuotes() async {
        isLoading = true
        loadError = nil
        do {
            let prefs = getUserPreferences?.execute() ?? UserPreferences()
            let fetched = try await getAllQuotes?.execute(filteredBy: prefs.selectedCategoryIds) ?? []
            quotes       = fetched.shuffled()
            currentIndex = 0
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
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
