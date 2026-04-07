import Foundation
import Combine

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var quotes: [Quote] = []
    @Published var isLoading = false
    @Published var selectedTab: String? = nil   // nil → Favoritos; anime name → categoría

    private let getCategoriesUseCase: GetCategoriesUseCase
    private let getQuotesByCategoryUseCase: GetQuotesByCategoryUseCase
    private let getFavoriteQuotesUseCase: GetFavoriteQuotesUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase

    private var loadTask: Task<Void, Never>?

    init(
        getCategoriesUseCase: GetCategoriesUseCase,
        getQuotesByCategoryUseCase: GetQuotesByCategoryUseCase,
        getFavoriteQuotesUseCase: GetFavoriteQuotesUseCase,
        toggleFavoriteUseCase: ToggleFavoriteUseCase,
        initialCategoryId: String? = nil
    ) {
        self.getCategoriesUseCase       = getCategoriesUseCase
        self.getQuotesByCategoryUseCase = getQuotesByCategoryUseCase
        self.getFavoriteQuotesUseCase   = getFavoriteQuotesUseCase
        self.toggleFavoriteUseCase      = toggleFavoriteUseCase
        self.selectedTab                = initialCategoryId
    }

    func onAppear() {
        Task {
            await loadCategories()
            await loadQuotes(for: selectedTab)
        }
    }

    func selectTab(_ tab: String?) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        loadTask?.cancel()
        loadTask = Task { await loadQuotes(for: tab) }
    }

    func toggleFavorite(_ quote: Quote) async {
        do {
            try await toggleFavoriteUseCase.execute(quote)
            if let idx = quotes.firstIndex(where: { $0.id == quote.id }) {
                quotes[idx].isFavorite.toggle()
            }
            // If in favorites tab and quote was unfavorited, remove it
            if selectedTab == nil, let idx = quotes.firstIndex(where: { $0.id == quote.id && !$0.isFavorite }) {
                quotes.remove(at: idx)
            }
        } catch {
            print("[CatalogViewModel] toggleFavorite error: \(error)")
        }
    }

    // MARK: Private

    private func loadCategories() async {
        do { categories = try await getCategoriesUseCase.execute() }
        catch { print("[CatalogViewModel] loadCategories error: \(error)") }
    }

    private func loadQuotes(for categoryId: String?) async {
        isLoading = true
        do {
            if let anime = categoryId {
                quotes = try await getQuotesByCategoryUseCase.execute(anime: anime)
            } else {
                quotes = try await getFavoriteQuotesUseCase.execute()
            }
        } catch {
            if !Task.isCancelled {
                print("[CatalogViewModel] loadQuotes error: \(error)")
            }
        }
        isLoading = false
    }
}
