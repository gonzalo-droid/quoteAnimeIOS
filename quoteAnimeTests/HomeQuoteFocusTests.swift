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

    private static func makeViewModel(
        selection: Set<String> = [],
        repository: FakeQuoteRepository = .withCatalogue([("Naruto", 5), ("One Piece", 5)])
    ) -> (HomeViewModel, AppRouter) {
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

    /// On launch `.onAppear` asks for a reload before the first load has finished. A second load
    /// used to start: a second fetch, a second reschedule, and a reshuffle that left the widget's
    /// page pointing at another quote.
    @Test("al arrancar el feed se carga una sola vez aunque Inicio aparezca durante la carga")
    func launchLoadsOnce() async {
        let repository = FakeQuoteRepository.withCatalogue([("Naruto", 5), ("One Piece", 5)])
        let (viewModel, _) = Self.makeViewModel(repository: repository)
        viewModel.focus(onQuoteId: "Naruto-2")

        await viewModel.reloadIfCategorySelectionChanged()   // `.onAppear`, mid-load
        await Self.waitForFirstLoad(viewModel)
        await viewModel.reloadIfCategorySelectionChanged()   // back from Settings, nothing changed
        // Let `setup`'s own load task run too, whichever order the executor picked.
        for _ in 0..<200 { await Task.yield() }

        #expect(repository.fetchCount == 1)
        let index = viewModel.quotes.firstIndex { $0.id == "Naruto-2" }
        #expect(index != nil)
        #expect(viewModel.scrollRequest == index)
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
