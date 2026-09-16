import Foundation
import Testing
@testable import quoteAnime

/// Android re-picks a quote on every notification fire, filtering by `selectedCategoryIds`
/// inside `QuoteNotificationWorker`. iOS has to pre-schedule the whole batch, so the filter is
/// applied once when the batch is built — these tests pin that the selection actually reaches
/// the scheduler, since a leak here would only show up hours later on a real device.
@Suite("Notificaciones: respetar la selección de animes")
struct RescheduleQuoteNotificationsUseCaseTests {

    private static let catalogue: [(anime: String, count: Int)] = [
        ("Naruto", 3),
        ("One Piece", 2),
        ("Vinland Saga", 4),
    ]

    private static func makeUseCase() -> (
        RescheduleQuoteNotificationsUseCase,
        FakeQuoteNotificationScheduler,
        FakeQuoteRepository
    ) {
        let repository = FakeQuoteRepository.withCatalogue(catalogue)
        let scheduler = FakeQuoteNotificationScheduler()
        let useCase = RescheduleQuoteNotificationsUseCase(
            getAllQuotes: GetAllQuotesUseCase(repository: repository),
            scheduler: scheduler
        )
        return (useCase, scheduler, repository)
    }

    private static func preferences(
        enabled: Bool = true,
        selection: Set<String> = []
    ) -> UserPreferences {
        var prefs = UserPreferences()
        prefs.notificationsEnabled = enabled
        prefs.selectedCategoryIds = selection
        return prefs
    }

    // MARK: - The selection reaches the scheduler

    @Test("sólo se programan frases de los animes elegidos")
    func schedulesOnlySelectedAnimes() async {
        let (useCase, scheduler, _) = Self.makeUseCase()

        await useCase.execute(preferences: Self.preferences(selection: ["Naruto", "One Piece"]))

        #expect(scheduler.scheduledBatches.count == 1)
        #expect(scheduler.lastScheduledAnimes == ["Naruto", "One Piece"])
        #expect(scheduler.lastScheduledQuotes?.count == 5)
    }

    @Test("sin selección se programa todo el catálogo")
    func emptySelectionSchedulesEverything() async {
        let (useCase, scheduler, _) = Self.makeUseCase()

        await useCase.execute(preferences: Self.preferences(selection: []))

        #expect(scheduler.lastScheduledQuotes?.count == 9)
        #expect(scheduler.lastScheduledAnimes == ["Naruto", "One Piece", "Vinland Saga"])
    }

    // MARK: - Pre-fetched pool (Home passing its feed)

    @Test("un pozo ya cargado se vuelve a filtrar, no se confía en el llamador")
    func providedPoolIsFilteredAgain() async {
        let (useCase, scheduler, repository) = Self.makeUseCase()
        let unfilteredPool = try! await repository.fetchAllQuotes()
        let fetchesBefore = repository.fetchCount

        await useCase.execute(
            preferences: Self.preferences(selection: ["Vinland Saga"]),
            pool: unfilteredPool
        )

        #expect(scheduler.lastScheduledAnimes == ["Vinland Saga"])
        #expect(scheduler.lastScheduledQuotes?.count == 4)
        // And it did not hit the repository again.
        #expect(repository.fetchCount == fetchesBefore)
    }

    @Test("sin pozo previo, sí se consulta el repositorio")
    func withoutPoolItFetches() async {
        let (useCase, _, repository) = Self.makeUseCase()

        await useCase.execute(preferences: Self.preferences())

        #expect(repository.fetchCount == 1)
    }

    // MARK: - Nothing to schedule

    @Test("con las notificaciones apagadas no se programa ni se consulta nada")
    func disabledSchedulesNothing() async {
        let (useCase, scheduler, repository) = Self.makeUseCase()

        await useCase.execute(preferences: Self.preferences(enabled: false, selection: ["Naruto"]))

        #expect(scheduler.scheduledBatches.isEmpty)
        #expect(repository.fetchCount == 0)
    }

    @Test("si la selección no deja ninguna frase, no se toca lo ya programado")
    func emptyResultLeavesPendingAlone() async {
        let (useCase, scheduler, _) = Self.makeUseCase()

        await useCase.execute(preferences: Self.preferences(selection: ["Anime Que No Existe"]))

        #expect(scheduler.scheduledBatches.isEmpty)
        #expect(scheduler.cancelAllCount == 0)
    }

    @Test("si el repositorio falla, no se programa nada y no se propaga el error")
    func repositoryFailureIsSwallowed() async {
        let (useCase, scheduler, repository) = Self.makeUseCase()
        repository.fetchError = FakeQuoteRepositoryError()

        await useCase.execute(preferences: Self.preferences(selection: ["Naruto"]))

        #expect(scheduler.scheduledBatches.isEmpty)
    }

    @Test("catálogo vacío no programa nada")
    func emptyCatalogueSchedulesNothing() async {
        let scheduler = FakeQuoteNotificationScheduler()
        let useCase = RescheduleQuoteNotificationsUseCase(
            getAllQuotes: GetAllQuotesUseCase(repository: FakeQuoteRepository(quotes: [])),
            scheduler: scheduler
        )

        await useCase.execute(preferences: Self.preferences())

        #expect(scheduler.scheduledBatches.isEmpty)
    }

    // MARK: - Changing the selection

    @Test("cambiar la selección reprograma con el nuevo pozo")
    func changingSelectionReschedules() async {
        let (useCase, scheduler, _) = Self.makeUseCase()

        await useCase.execute(preferences: Self.preferences(selection: ["Naruto"]))
        await useCase.execute(preferences: Self.preferences(selection: ["One Piece"]))

        #expect(scheduler.scheduledBatches.count == 2)
        #expect(Set(scheduler.scheduledBatches[0].map(\.anime)) == ["Naruto"])
        #expect(Set(scheduler.scheduledBatches[1].map(\.anime)) == ["One Piece"])
    }
}
