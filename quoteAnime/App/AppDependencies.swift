import Foundation
import Combine
import SwiftData
import UserNotifications

/// Composition root. Creates and wires all dependencies manually.
/// Must be used as `@StateObject` at the App level.
@MainActor
final class AppDependencies: ObservableObject {
    // MARK: Repositories
    let quoteRepository: QuoteRepository
    let preferencesRepository: UserPreferencesRepository

    // MARK: Use Cases — Quotes
    let getAllQuotesUseCase: GetAllQuotesUseCase
    let getCategoriesUseCase: GetCategoriesUseCase
    let getQuotesByCategoryUseCase: GetQuotesByCategoryUseCase
    let getRandomQuoteUseCase: GetRandomQuoteUseCase
    let getFavoriteQuotesUseCase: GetFavoriteQuotesUseCase
    let toggleFavoriteUseCase: ToggleFavoriteUseCase
    let observeFavoriteStatusUseCase: ObserveFavoriteStatusUseCase

    // MARK: Use Cases — Preferences
    let getUserPreferencesUseCase: GetUserPreferencesUseCase
    let updateUserPreferencesUseCase: UpdateUserPreferencesUseCase
    let getOnboardingCompletedUseCase: GetOnboardingCompletedUseCase
    let setOnboardingCompletedUseCase: SetOnboardingCompletedUseCase

    // MARK: Services
    let notificationScheduler: NotificationScheduler
    let rescheduleQuoteNotificationsUseCase: RescheduleQuoteNotificationsUseCase
    /// Refills the quote notifications from a `BGAppRefreshTask` while the app stays closed.
    let quoteNotificationBackgroundRefresh: QuoteNotificationBackgroundRefresh

    // MARK: Habits ("Mi Rutina") — SwiftData-only, nil below iOS 17 (no legacy fallback yet)
    let habitRepository: HabitRepository?
    /// Mock or StoreKit, decided by `PremiumConfig.usesRealBilling` — see `PremiumServices`.
    let premium = PremiumServices.live
    var premiumGate: PremiumGate { premium.gate }
    var getActiveHabitsUseCase: GetActiveHabitsUseCase?
    var getArchivedHabitsUseCase: GetArchivedHabitsUseCase?
    var getGlobalStreakUseCase: GetGlobalStreakUseCase?
    var toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase?
    var createHabitUseCase: CreateHabitUseCase?
    var updateHabitUseCase: UpdateHabitUseCase?
    var archiveHabitUseCase: ArchiveHabitUseCase?
    var unarchiveHabitUseCase: UnarchiveHabitUseCase?
    var deleteHabitUseCase: DeleteHabitUseCase?
    /// Bundled suggestions at once, `/habitTemplates` (Realtime Database) when it answers.
    let getHabitTemplatesUseCase = GetHabitTemplatesUseCase(remote: FirebaseHabitTemplateRemoteDataSource())
    let habitReminderScheduler = HabitReminderScheduler()
    /// Single entry point for keeping the home-screen widgets in sync, mirroring Android's
    /// `RoutineWidgetScheduler`. A no-op below iOS 17, where there is no habit store to read.
    var routineWidgetRefresher: RoutineWidgetRefreshing = NoopRoutineWidgetRefresher()
    /// "Mi Rutina" events in Firebase Analytics, with Android's names — see `RoutineAnalytics`.
    let routineAnalytics: RoutineAnalytics = FirebaseRoutineAnalytics()

    /// Whether "Mi Rutina" can run at all. False below iOS 17 (SwiftData) and also when the
    /// `ModelContainer` fails to build. Entry points to the feature must check this and hide
    /// themselves rather than navigating to a screen that can only apologise.
    var isRoutineAvailable: Bool { habitRepository != nil }

    /// Kept alive here — `UNUserNotificationCenter.current().delegate` is `weak`.
    private var habitReminderNotificationDelegate: HabitReminderNotificationDelegate?

    /// One file per schema. Changing either string points the app at a different (empty) store,
    /// so treat them as data, not as labels.
    private static let favoritesStoreName = "Favorites"
    private static let habitsStoreName = "Habits"

    init() {
        // ── Favorite storage (SwiftData on iOS 17+, UserDefaults fallback) ──
        //
        // The store is NAMED. An unnamed `ModelConfiguration` defaults every store to the same
        // file ("default.store"), and this app builds two containers with two different
        // schemas — favorites here, habits below. Both opened that one file, each found it
        // incompatible with its own model, and SwiftData recreated it from scratch: every
        // launch wiped whatever the other container had written the session before. Naming
        // them gives each its own file. Never make either configuration anonymous again.
        var favoriteStorage: FavoriteStorageProtocol = UserDefaultsFavoriteStorage()
        if #available(iOS 17, *) {
            do {
                let schema = Schema([FavoriteQuoteModel.self])
                let config = ModelConfiguration(Self.favoritesStoreName, schema: schema)
                let container = try ModelContainer(for: schema, configurations: [config])
                let context = ModelContext(container)
                favoriteStorage = FavoriteQuoteDAO(modelContext: context)
            } catch {
                print("[AppDependencies] SwiftData unavailable, using UserDefaults: \(error)")
            }
        }

        // ── Remote data sources ──
        let remote     = QuoteRemoteDataSource()
        let imagesDS   = AnimeImagesRemoteDataSource()

        // ── Repositories ──
        let quoteRepo = QuoteRepositoryImpl(
            remoteDataSource: remote,
            imagesDataSource: imagesDS,
            favoriteStorage: favoriteStorage
        )
        self.quoteRepository = quoteRepo

        let prefStore = UserPreferencesStore()
        let prefRepo  = UserPreferencesRepositoryImpl(store: prefStore)
        self.preferencesRepository = prefRepo

        // ── Use Cases ──
        self.getAllQuotesUseCase            = GetAllQuotesUseCase(repository: quoteRepo)
        self.getCategoriesUseCase           = GetCategoriesUseCase(repository: quoteRepo)
        self.getQuotesByCategoryUseCase     = GetQuotesByCategoryUseCase(repository: quoteRepo)
        self.getRandomQuoteUseCase          = GetRandomQuoteUseCase(repository: quoteRepo)
        self.getFavoriteQuotesUseCase       = GetFavoriteQuotesUseCase(repository: quoteRepo)
        self.toggleFavoriteUseCase          = ToggleFavoriteUseCase(repository: quoteRepo)
        self.observeFavoriteStatusUseCase   = ObserveFavoriteStatusUseCase(repository: quoteRepo)
        self.getUserPreferencesUseCase      = GetUserPreferencesUseCase(repository: prefRepo)
        self.updateUserPreferencesUseCase   = UpdateUserPreferencesUseCase(repository: prefRepo)
        self.getOnboardingCompletedUseCase  = GetOnboardingCompletedUseCase(repository: prefRepo)
        self.setOnboardingCompletedUseCase  = SetOnboardingCompletedUseCase(repository: prefRepo)

        // ── Services ──
        let scheduler = NotificationScheduler()
        self.notificationScheduler = scheduler
        self.rescheduleQuoteNotificationsUseCase = RescheduleQuoteNotificationsUseCase(
            getAllQuotes: self.getAllQuotesUseCase,
            scheduler: scheduler
        )
        self.quoteNotificationBackgroundRefresh = QuoteNotificationBackgroundRefresh(
            getPreferences: self.getUserPreferencesUseCase,
            reschedule: self.rescheduleQuoteNotificationsUseCase
        )

        // ── Habits ("Mi Rutina") — SwiftData only, nil below iOS 17 ──
        var habitRepo: HabitRepository?
        if #available(iOS 17, *) {
            do {
                let schema = Schema([HabitModel.self, HabitCompletionModel.self])
                // Named for the same reason as the favorites store above — see that comment.
                let config = ModelConfiguration(Self.habitsStoreName, schema: schema)
                let container = try ModelContainer(for: schema, configurations: [config])
                habitRepo = HabitDAO(modelContext: ModelContext(container))
            } catch {
                print("[AppDependencies] Habit SwiftData unavailable: \(error)")
            }
        }
        self.habitRepository = habitRepo
        if let habitRepo {
            self.getActiveHabitsUseCase = GetActiveHabitsUseCase(repository: habitRepo)
            self.getArchivedHabitsUseCase = GetArchivedHabitsUseCase(repository: habitRepo)
            self.getGlobalStreakUseCase = GetGlobalStreakUseCase(repository: habitRepo)
            self.toggleHabitCompletionUseCase = ToggleHabitCompletionUseCase(repository: habitRepo)
            self.createHabitUseCase = CreateHabitUseCase(repository: habitRepo, premiumGate: premiumGate)
            self.updateHabitUseCase = UpdateHabitUseCase(repository: habitRepo)
            self.archiveHabitUseCase = ArchiveHabitUseCase(repository: habitRepo)
            self.unarchiveHabitUseCase = UnarchiveHabitUseCase(repository: habitRepo)
            self.deleteHabitUseCase = DeleteHabitUseCase(repository: habitRepo)

            let refresher = RoutineWidgetRefresher(
                getActiveHabits: GetActiveHabitsUseCase(repository: habitRepo),
                getArchivedHabits: GetArchivedHabitsUseCase(repository: habitRepo),
                getGlobalStreak: GetGlobalStreakUseCase(repository: habitRepo)
            )
            self.routineWidgetRefresher = refresher

            HabitReminderScheduler.registerCategory()
            let delegate = HabitReminderNotificationDelegate(
                markDone: HabitReminderDoneAction(
                    repository: habitRepo,
                    toggleHabitCompletion: ToggleHabitCompletionUseCase(repository: habitRepo),
                    analytics: routineAnalytics
                ),
                routineWidgetRefresher: refresher
            )
            self.habitReminderNotificationDelegate = delegate
            UNUserNotificationCenter.current().delegate = delegate
        }
    }

    /// Hands a tapped habit reminder to the router — `AppRouter.open(_:)`, the same door the
    /// widgets' URL goes through. A no-op below iOS 17, where there is no delegate.
    func routeNotificationTaps(to open: @escaping (AppDeepLink) -> Void) {
        habitReminderNotificationDelegate?.openDeepLink = open
    }
}
