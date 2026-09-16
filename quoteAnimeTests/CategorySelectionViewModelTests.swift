import Foundation
import Testing
@testable import quoteAnime

/// Mirrors Android's `SettingsViewModel.onCategoryToggled` / `onSelectAllCategories`: every tap
/// persists immediately and reprograms the notifications, and an empty set means "all animes".
@MainActor
@Suite("CategorySelectionViewModel")
struct CategorySelectionViewModelTests {

    private struct Harness {
        let viewModel: CategorySelectionViewModel
        let preferences: FakeUserPreferencesRepository
        let scheduler: FakeQuoteNotificationScheduler
        let quotes: FakeQuoteRepository
    }

    private static func makeHarness(
        notificationsEnabled: Bool = true,
        selection: Set<String> = []
    ) -> Harness {
        var prefs = UserPreferences()
        prefs.notificationsEnabled = notificationsEnabled
        prefs.selectedCategoryIds = selection

        let preferences = FakeUserPreferencesRepository(preferences: prefs)
        let quotes = FakeQuoteRepository.withCatalogue([
            ("Naruto", 3), ("One Piece", 2), ("Vinland Saga", 4),
        ])
        let scheduler = FakeQuoteNotificationScheduler()

        let viewModel = CategorySelectionViewModel(
            getCategories: GetCategoriesUseCase(repository: quotes),
            getUserPreferences: GetUserPreferencesUseCase(repository: preferences),
            updateUserPreferences: UpdateUserPreferencesUseCase(repository: preferences),
            rescheduleNotifications: RescheduleQuoteNotificationsUseCase(
                getAllQuotes: GetAllQuotesUseCase(repository: quotes),
                scheduler: scheduler
            )
        )
        return Harness(viewModel: viewModel, preferences: preferences, scheduler: scheduler, quotes: quotes)
    }

    /// The persist path fires a detached Task; give it a turn before asserting on the scheduler.
    private static func settle() async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    // MARK: - Loading

    @Test("carga los animes del catálogo, ordenados y sin repetir")
    func loadsCategories() async {
        let harness = Self.makeHarness()

        await harness.viewModel.load()

        #expect(harness.viewModel.categories.map(\.id) == ["Naruto", "One Piece", "Vinland Saga"])
        #expect(harness.viewModel.isLoading == false)
        #expect(harness.viewModel.loadFailed == false)
    }

    @Test("arranca mostrando la selección ya guardada")
    func loadsExistingSelection() async {
        let harness = Self.makeHarness(selection: ["Naruto"])

        await harness.viewModel.load()

        #expect(harness.viewModel.isSelected("Naruto"))
        #expect(!harness.viewModel.isSelected("One Piece"))
        #expect(!harness.viewModel.allSelected)
    }

    @Test("si el catálogo falla, se marca el error y no se rompe")
    func loadFailureIsSurfaced() async {
        let harness = Self.makeHarness()
        harness.quotes.fetchError = FakeQuoteRepositoryError()

        await harness.viewModel.load()

        #expect(harness.viewModel.loadFailed)
        #expect(harness.viewModel.categories.isEmpty)
        #expect(harness.viewModel.isLoading == false)
    }

    // MARK: - Selecting

    @Test("elegir un anime lo persiste y reprograma las notificaciones con ese pozo")
    func togglePersistsAndReschedules() async {
        let harness = Self.makeHarness()
        await harness.viewModel.load()

        harness.viewModel.toggle("Naruto")
        await Self.settle()

        #expect(harness.preferences.preferences.selectedCategoryIds == ["Naruto"])
        #expect(harness.scheduler.lastScheduledAnimes == ["Naruto"])
    }

    @Test("elegir dos animes acumula la selección")
    func togglingTwoAnimes() async {
        let harness = Self.makeHarness()
        await harness.viewModel.load()

        harness.viewModel.toggle("Naruto")
        harness.viewModel.toggle("Vinland Saga")
        await Self.settle()

        #expect(harness.viewModel.selectedIds == ["Naruto", "Vinland Saga"])
        #expect(harness.preferences.preferences.selectedCategoryIds == ["Naruto", "Vinland Saga"])
        #expect(harness.scheduler.lastScheduledAnimes == ["Naruto", "Vinland Saga"])
    }

    @Test("volver a tocar un anime elegido lo quita")
    func toggleTwiceRemoves() async {
        let harness = Self.makeHarness(selection: ["Naruto", "One Piece"])
        await harness.viewModel.load()

        harness.viewModel.toggle("Naruto")
        await Self.settle()

        #expect(harness.viewModel.selectedIds == ["One Piece"])
        #expect(harness.preferences.preferences.selectedCategoryIds == ["One Piece"])
    }

    @Test("quitar el último anime equivale a 'Todos' (set vacío), igual que en Android")
    func removingLastSelectionMeansAll() async {
        let harness = Self.makeHarness(selection: ["Naruto"])
        await harness.viewModel.load()

        harness.viewModel.toggle("Naruto")
        await Self.settle()

        #expect(harness.viewModel.allSelected)
        #expect(harness.preferences.preferences.selectedCategoryIds.isEmpty)
        #expect(harness.scheduler.lastScheduledQuotes?.count == 9)
    }

    // MARK: - "Todas"

    @Test("'Todos los animes' limpia la selección y reprograma con todo el catálogo")
    func selectAllClearsSelection() async {
        let harness = Self.makeHarness(selection: ["Naruto"])
        await harness.viewModel.load()

        harness.viewModel.selectAll()
        await Self.settle()

        #expect(harness.viewModel.allSelected)
        #expect(harness.preferences.preferences.selectedCategoryIds.isEmpty)
        #expect(harness.scheduler.lastScheduledAnimes == ["Naruto", "One Piece", "Vinland Saga"])
    }

    @Test("tocar 'Todos' cuando ya está activo no escribe ni reprograma de nuevo")
    func selectAllIsNoOpWhenAlreadyAll() async {
        let harness = Self.makeHarness(selection: [])
        await harness.viewModel.load()

        harness.viewModel.selectAll()
        await Self.settle()

        #expect(harness.preferences.saveCount == 0)
        #expect(harness.scheduler.scheduledBatches.isEmpty)
    }

    // MARK: - Notifications off

    @Test("con las notificaciones apagadas la selección se guarda igual, sin programar nada")
    func selectionPersistsWithNotificationsOff() async {
        let harness = Self.makeHarness(notificationsEnabled: false)
        await harness.viewModel.load()

        harness.viewModel.toggle("Naruto")
        await Self.settle()

        #expect(harness.preferences.preferences.selectedCategoryIds == ["Naruto"])
        #expect(harness.scheduler.scheduledBatches.isEmpty)
    }

    // MARK: - Boundaries

    @Test("elegir todos los animes uno por uno no es lo mismo que 'Todos', pero da el mismo pozo")
    func selectingEveryAnimeIndividually() async {
        let harness = Self.makeHarness()
        await harness.viewModel.load()

        for category in harness.viewModel.categories {
            harness.viewModel.toggle(category.id)
        }
        await Self.settle()

        #expect(!harness.viewModel.allSelected)
        #expect(harness.viewModel.selectedIds.count == 3)
        #expect(harness.scheduler.lastScheduledQuotes?.count == 9)
    }
}
