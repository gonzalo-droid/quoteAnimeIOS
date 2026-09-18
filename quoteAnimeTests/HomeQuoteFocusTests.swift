import Foundation
import Testing
@testable import quoteAnime

/// Tapping the quote widget opens Home positioned on that quote — Android's `HomeViewModel`
/// with the `quoteId` nav argument (`scrollToPage = indexOfFirst { it.id == widgetQuoteId }`).
/// Android's feed is never filtered by anime; iOS's is, so a quote outside the selection is one
/// more way for the id not to be there — and it must fall back like a missing one.
@MainActor
@Suite("Widget de frases: Inicio en esa frase")
struct HomeQuoteFocusTests {

    private static func makeViewModel(selection: Set<String> = []) -> (HomeViewModel, AppRouter) {
        let repository = FakeQuoteRepository.withCatalogue([("Naruto", 5), ("One Piece", 5)])
        var prefs = UserPreferences()
        prefs.selectedCategoryIds = selection
        let preferences = FakeUserPreferencesRepository(preferences: prefs)
        let router = AppRouter()
        let viewModel = HomeViewModel()
        viewModel.setup(
            getAllQuotes: GetAllQuotesUseCase(repository: repository),
            toggleFavorite: ToggleFavoriteUseCase(repository: repository),
            getUserPreferences: GetUserPreferencesUseCase(repository: preferences),
            rescheduleNotifications: RescheduleQuoteNotificationsUseCase(
                getAllQuotes: GetAllQuotesUseCase(repository: repository),
                scheduler: FakeQuoteNotificationScheduler()
            ),
            router: router
        )
        return (viewModel, router)
    }

    /// `setup` starts the feed's first load in its own task; wait for that one instead of
    /// starting a second load that would race it (and reshuffle the feed under the test).
    private static func waitForFirstLoad(_ viewModel: HomeViewModel) async {
        var spins = 0
        while viewModel.isLoading, spins < 1_000 {
            await Task.yield()
            spins += 1
        }
        #expect(!viewModel.isLoading, "el feed nunca terminó de cargar")
    }

    @Test("arranque en frío: el pedido llega antes que el feed y se aplica al cargar")
    func coldStartWaitsForTheFeed() async {
        let (viewModel, _) = Self.makeViewModel()
        #expect(viewModel.isLoading)

        viewModel.focus(onQuoteId: "One Piece-3")
        #expect(viewModel.scrollRequest == nil)

        await Self.waitForFirstLoad(viewModel)
        let index = viewModel.quotes.firstIndex { $0.id == "One Piece-3" }
        #expect(index != nil)
        #expect(viewModel.scrollRequest == index)
        #expect(viewModel.currentIndex == index)
    }

    @Test("con el feed ya cargado, se posiciona en el acto")
    func warmFocus() async {
        let (viewModel, _) = Self.makeViewModel()
        await Self.waitForFirstLoad(viewModel)

        viewModel.focus(onQuoteId: "Naruto-1")
        let index = viewModel.quotes.firstIndex { $0.id == "Naruto-1" }
        #expect(index != nil)
        #expect(viewModel.scrollRequest == index)

        viewModel.scrollRequestConsumed()
        #expect(viewModel.scrollRequest == nil)
    }

    @Test("frase que ya no existe: Inicio se abre donde estaba, sin error")
    func missingQuote() async {
        let (viewModel, _) = Self.makeViewModel()
        await Self.waitForFirstLoad(viewModel)
        viewModel.currentIndex = 4

        viewModel.focus(onQuoteId: "borrada-99")
        #expect(viewModel.scrollRequest == nil)
        #expect(viewModel.currentIndex == 4)
        #expect(viewModel.loadError == nil)
        #expect(viewModel.quotes.count == 10)
    }

    @Test("frase fuera de los animes elegidos: el feed no se toca y no se posiciona")
    func quoteOutsideTheSelection() async {
        let (viewModel, _) = Self.makeViewModel(selection: ["Naruto"])
        viewModel.focus(onQuoteId: "One Piece-2")
        await Self.waitForFirstLoad(viewModel)

        #expect(viewModel.scrollRequest == nil)
        #expect(viewModel.quotes.count == 5)
        #expect(Set(viewModel.quotes.map(\.anime)) == ["Naruto"])
    }

    @Test("un pedido fallido no queda colgado para la próxima recarga")
    func failedRequestIsDropped() async {
        let (viewModel, _) = Self.makeViewModel(selection: ["Naruto"])
        viewModel.focus(onQuoteId: "One Piece-2")
        await Self.waitForFirstLoad(viewModel)
        await viewModel.loadQuotes()
        #expect(viewModel.scrollRequest == nil)
    }
}
