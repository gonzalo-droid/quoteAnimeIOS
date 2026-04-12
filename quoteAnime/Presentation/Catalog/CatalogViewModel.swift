import SwiftUI
import Combine

// MARK: - Filter

enum CatalogFilter: Equatable {
    case favorites
    case all
    case byEmotion(categoryId: String, label: String)

    var label: String {
        switch self {
        case .favorites:                    return "Favoritos"
        case .all:                          return "Todas"
        case .byEmotion(_, let label):      return label
        }
    }
}

// MARK: - Emotion categories (hardcoded)

struct EmotionCategory: Identifiable {
    let id: String
    let label: String
    let emoji: String
    let color: Color
}

let allEmotionCategories: [EmotionCategory] = [
    EmotionCategory(id: "motivacion", label: "Motivación",  emoji: "⚡", color: Color(hex: "#E67E22")),
    EmotionCategory(id: "lucha",      label: "Lucha",       emoji: "🛡", color: Color(hex: "#C0392B")),
    EmotionCategory(id: "tristeza",   label: "Tristeza",    emoji: "💧", color: Color(hex: "#5D8AA8")),
    EmotionCategory(id: "amor",       label: "Amor",        emoji: "❤️", color: Color(hex: "#FF6B8A")),
    EmotionCategory(id: "amistad",    label: "Amistad",     emoji: "👥", color: Color(hex: "#27AE60")),
    EmotionCategory(id: "reflexion",  label: "Reflexión",   emoji: "🧠", color: Color(hex: "#A78BFA")),
    EmotionCategory(id: "soledad",    label: "Soledad",     emoji: "🌙", color: Color(hex: "#4A4A5A")),
    EmotionCategory(id: "sacrificio", label: "Sacrificio",  emoji: "🧘", color: Color(hex: "#8B2252")),
    EmotionCategory(id: "esperanza",  label: "Esperanza",   emoji: "☀️", color: Color(hex: "#F1C40F")),
    EmotionCategory(id: "orgullo",    label: "Orgullo",     emoji: "🏆", color: Color(hex: "#F39C12")),
]

// MARK: - UI State

struct CatalogUiState {
    var selectedFilter: CatalogFilter? = nil   // nil = Selector screen
    var selectedQuote: Quote? = nil            // non-nil = Detail screen
    var quotes: [Quote] = []
    var isLoading: Bool = false
    var isEmpty: Bool { !isLoading && quotes.isEmpty }
}

// MARK: - ViewModel

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published var uiState = CatalogUiState()
    @Published var showShareSheet = false
    @Published var shareImage: UIImage? = nil

    private let getAllQuotesUseCase: GetAllQuotesUseCase
    private let getFavoriteQuotesUseCase: GetFavoriteQuotesUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private var allQuotesCache: [Quote] = []
    private var loadTask: Task<Void, Never>?

    init(
        getAllQuotesUseCase: GetAllQuotesUseCase,
        getFavoriteQuotesUseCase: GetFavoriteQuotesUseCase,
        toggleFavoriteUseCase: ToggleFavoriteUseCase
    ) {
        self.getAllQuotesUseCase    = getAllQuotesUseCase
        self.getFavoriteQuotesUseCase = getFavoriteQuotesUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
    }

    // MARK: - Actions

    func onAppear() {
        guard allQuotesCache.isEmpty else { return }
        Task { await preloadAllQuotes() }
    }

    func onFilterSelected(_ filter: CatalogFilter) {
        uiState.selectedFilter = filter
        uiState.selectedQuote  = nil
        loadTask?.cancel()
        loadTask = Task { await loadQuotes(for: filter) }
    }

    func onBackFromList() {
        uiState.selectedFilter = nil
        uiState.selectedQuote  = nil
        uiState.quotes         = []
    }

    func onQuoteSelected(_ quote: Quote) {
        uiState.selectedQuote = quote
    }

    func onBackFromDetail() {
        uiState.selectedQuote = nil
    }

    func onToggleFavorite(_ quote: Quote) {
        Task {
            do {
                try await toggleFavoriteUseCase.execute(quote)
                let newFav = !quote.isFavorite
                // Update in list
                if let idx = uiState.quotes.firstIndex(where: { $0.id == quote.id }) {
                    uiState.quotes[idx].isFavorite = newFav
                }
                // Update in detail
                if uiState.selectedQuote?.id == quote.id {
                    uiState.selectedQuote?.isFavorite = newFav
                }
                // If in favorites tab and quote was unfavorited, remove it
                if uiState.selectedFilter == .favorites && !newFav {
                    uiState.quotes.removeAll { $0.id == quote.id }
                    if uiState.selectedQuote?.id == quote.id { uiState.selectedQuote = nil }
                }
            } catch {
                print("[CatalogViewModel] toggleFavorite error: \(error)")
            }
        }
    }

    func buildShareImage(for quote: Quote) {
        Task {
            shareImage = await ShareImageRenderer.fetchAndRender(quote: quote)
            if shareImage != nil { showShareSheet = true }
        }
    }

    // MARK: - Private

    private func preloadAllQuotes() async {
        do {
            allQuotesCache = try await getAllQuotesUseCase.execute()
        } catch {
            print("[CatalogViewModel] preload error: \(error)")
        }
    }

    private func loadQuotes(for filter: CatalogFilter) async {
        uiState.isLoading = true
        do {
            switch filter {
            case .favorites:
                uiState.quotes = try await getFavoriteQuotesUseCase.execute()
            case .all:
                if allQuotesCache.isEmpty { await preloadAllQuotes() }
                uiState.quotes = allQuotesCache
            case .byEmotion(let categoryId, _):
                if allQuotesCache.isEmpty { await preloadAllQuotes() }
                uiState.quotes = allQuotesCache.filter { $0.categories.contains(categoryId) }
            }
        } catch {
            if !Task.isCancelled {
                print("[CatalogViewModel] loadQuotes error: \(error)")
            }
        }
        uiState.isLoading = false
    }
}
