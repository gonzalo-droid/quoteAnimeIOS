import Foundation
import Testing
@testable import quoteAnime

/// iOS books quote notifications in advance and used to refill them only when Home appeared, so
/// an app left closed ran dry. These pin the background refill: what it asks `BGTaskScheduler`
/// for, that it reuses the one reschedule path (which only touches `quote_*` requests), and the
/// "open the app" notice that closes every batch in case iOS never runs the task.
@Suite("Notificaciones: reposición en segundo plano")
@MainActor
struct QuoteNotificationBackgroundRefreshTests {

    private static let now = Date(timeIntervalSince1970: 1_790_000_000)

    private static func makeSUT(enabled: Bool = true, selection: Set<String> = []) -> (
        QuoteNotificationBackgroundRefresh,
        FakeAppRefreshScheduler,
        FakeQuoteNotificationScheduler
    ) {
        var prefs = UserPreferences()
        prefs.notificationsEnabled = enabled
        prefs.selectedCategoryIds = selection
        let preferences = FakeUserPreferencesRepository(preferences: prefs)
        let notifications = FakeQuoteNotificationScheduler()
        let refreshScheduler = FakeAppRefreshScheduler()
        let refresh = QuoteNotificationBackgroundRefresh(
            getPreferences: GetUserPreferencesUseCase(repository: preferences),
            reschedule: RescheduleQuoteNotificationsUseCase(
                getAllQuotes: GetAllQuotesUseCase(
                    repository: FakeQuoteRepository.withCatalogue([("Naruto", 3), ("One Piece", 2)])
                ),
                scheduler: notifications
            ),
            scheduler: refreshScheduler,
            now: { now }
        )
        return (refresh, refreshScheduler, notifications)
    }

    // MARK: - Asking iOS for the next run

    @Test("con las notificaciones activas pide la próxima reposición en un día")
    func schedulesNextRefreshInADay() {
        let (refresh, scheduler, _) = Self.makeSUT()

        refresh.scheduleNext()

        #expect(scheduler.submissions == [
            .init(identifier: QuoteNotificationBackgroundRefresh.taskIdentifier,
                  earliestBeginDate: Self.now.addingTimeInterval(24 * 60 * 60))
        ])
        #expect(scheduler.cancelledIdentifiers.isEmpty)
    }

    @Test("con las notificaciones apagadas retira el pedido")
    func cancelsWhenNotificationsAreOff() {
        let (refresh, scheduler, _) = Self.makeSUT(enabled: false)

        refresh.scheduleNext()

        #expect(scheduler.submissions.isEmpty)
        #expect(scheduler.cancelledIdentifiers == [QuoteNotificationBackgroundRefresh.taskIdentifier])
    }

    @Test("si iOS rechaza el pedido no se rompe nada")
    func refusedSubmissionIsHarmless() async {
        let (refresh, scheduler, notifications) = Self.makeSUT()
        scheduler.refuses = true

        await refresh.run()

        #expect(scheduler.submissions.isEmpty)
        #expect(notifications.scheduledBatches.count == 1, "la reposición corre aunque no se pueda pedir la siguiente")
    }

    // MARK: - The task body

    @Test("la tarea vuelve a programar las frases con la selección de animes")
    func runRefillsWithTheSelection() async {
        let (refresh, _, notifications) = Self.makeSUT(selection: ["One Piece"])

        await refresh.run()

        #expect(notifications.scheduledBatches.count == 1)
        #expect(notifications.lastScheduledAnimes == ["One Piece"])
    }

    @Test("la tarea pide la siguiente antes de reponer")
    func runBooksTheNextRequest() async {
        let (refresh, scheduler, _) = Self.makeSUT()

        await refresh.run()

        #expect(scheduler.submissions.count == 1)
    }

    @Test("la tarea no cancela nada: los recordatorios de hábitos no se tocan")
    func runNeverCancels() async {
        let (refresh, _, notifications) = Self.makeSUT()

        await refresh.run()

        #expect(notifications.cancelQuoteNotificationsCount == 0)
    }

    @Test("con las notificaciones apagadas la tarea no programa frases")
    func runDoesNothingWhenOff() async {
        let (refresh, scheduler, notifications) = Self.makeSUT(enabled: false)

        await refresh.run()

        #expect(notifications.scheduledBatches.isEmpty)
        #expect(scheduler.cancelledIdentifiers == [QuoteNotificationBackgroundRefresh.taskIdentifier])
    }

    // MARK: - Info.plist

    @Test("el identificador de la tarea está permitido en el Info.plist")
    func identifierIsPermitted() {
        let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        #expect(permitted?.contains(QuoteNotificationBackgroundRefresh.taskIdentifier) == true)
    }

    @Test("el Info.plist declara el modo de segundo plano fetch")
    func fetchBackgroundModeIsDeclared() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        #expect(modes?.contains("fetch") == true)
    }

    // MARK: - The notice slot

    @Test("sólo el último horario de la tanda es el aviso", arguments: [
        (index: 0, count: 64, notice: false),
        (index: 62, count: 64, notice: false),
        (index: 63, count: 64, notice: true),
        (index: 0, count: 2, notice: false),
        (index: 1, count: 2, notice: true),
        (index: 0, count: 1, notice: false),
    ])
    func noticeIsTheLastSlot(index: Int, count: Int, notice: Bool) {
        #expect(NotificationScheduler.isRefillNotice(index: index, of: count) == notice)
    }

    @Test("el aviso no es una frase y está traducido")
    func noticeContent() {
        let content = NotificationHelper.makeRefillNoticeContent()
        #expect(!content.title.isEmpty)
        #expect(!content.body.isEmpty)
        #expect(content.sound != nil)
    }
}
