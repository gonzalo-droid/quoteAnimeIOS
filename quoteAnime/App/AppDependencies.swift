import Foundation
import Combine
import SwiftData

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

    // MARK: Habits ("Mi Rutina") — SwiftData-only, nil below iOS 17 (no legacy fallback yet)
    let habitRepository: HabitRepository?
    let premiumGate = PremiumGate()
    var getActiveHabitsUseCase: GetActiveHabitsUseCase?
    var getArchivedHabitsUseCase: GetArchivedHabitsUseCase?
    var getGlobalStreakUseCase: GetGlobalStreakUseCase?
    var toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase?
    var createHabitUseCase: CreateHabitUseCase?
    var updateHabitUseCase: UpdateHabitUseCase?
    var archiveHabitUseCase: ArchiveHabitUseCase?
    var unarchiveHabitUseCase: UnarchiveHabitUseCase?
    var deleteHabitUseCase: DeleteHabitUseCase?
    var getHabitTemplatesUseCase = GetHabitTemplatesUseCase()

    init() {
        // ── Favorite storage (SwiftData on iOS 17+, UserDefaults fallback) ──
        var favoriteStorage: FavoriteStorageProtocol = UserDefaultsFavoriteStorage()
        if #available(iOS 17, *) {
            do {
                let schema = Schema([FavoriteQuoteModel.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
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
        self.notificationScheduler = NotificationScheduler()

        // ── Habits ("Mi Rutina") — SwiftData only, nil below iOS 17 ──
        var habitRepo: HabitRepository?
        if #available(iOS 17, *) {
            do {
                let schema = Schema([HabitModel.self, HabitCompletionModel.self])
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
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
        }
    }
}
