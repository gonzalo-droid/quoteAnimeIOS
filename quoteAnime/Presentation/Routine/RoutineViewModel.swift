import SwiftUI
import Combine

enum RoutineFilter: Equatable {
    case active
    case archived
}

struct RoutineUiState {
    var filter: RoutineFilter = .active
    var habits: [HabitWithProgress] = []
    /// Always the active-habit count, regardless of `filter` — drives the habit limit even
    /// while browsing archived habits.
    var activeCount: Int = 0
    var globalStreak: StreakState = StreakState()
    var isLoading: Bool = false
    var maxHabits: Int = PremiumGate.freeHabitLimit
    var canAddHabit: Bool { activeCount < maxHabits }
    var isEmpty: Bool { !isLoading && habits.isEmpty }
}

@MainActor
final class RoutineViewModel: ObservableObject {
    @Published var uiState = RoutineUiState()

    private let getActiveHabitsUseCase: GetActiveHabitsUseCase
    private let getArchivedHabitsUseCase: GetArchivedHabitsUseCase
    private let getGlobalStreakUseCase: GetGlobalStreakUseCase
    private let toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase
    private let archiveHabitUseCase: ArchiveHabitUseCase
    private let unarchiveHabitUseCase: UnarchiveHabitUseCase
    private let deleteHabitUseCase: DeleteHabitUseCase
    private let habitReminderScheduler: HabitReminderScheduling
    private let routineWidgetRefresher: RoutineWidgetRefreshing
    private let premiumGate: PremiumGate
    private let analytics: RoutineAnalytics
    /// `routine_tab_opened` once per visit: `onAppear` also fires on the way back from a habit's
    /// detail, which Android's `init {}` never sees.
    private var didTrackOpen = false
    /// "Now", injectable so a test can pin the day the streaks are computed on.
    private let clock: () -> Date

    init(
        getActiveHabitsUseCase: GetActiveHabitsUseCase,
        getArchivedHabitsUseCase: GetArchivedHabitsUseCase,
        getGlobalStreakUseCase: GetGlobalStreakUseCase,
        toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase,
        archiveHabitUseCase: ArchiveHabitUseCase,
        unarchiveHabitUseCase: UnarchiveHabitUseCase,
        deleteHabitUseCase: DeleteHabitUseCase,
        habitReminderScheduler: HabitReminderScheduling,
        routineWidgetRefresher: RoutineWidgetRefreshing,
        premiumGate: PremiumGate,
        analytics: RoutineAnalytics = NoopRoutineAnalytics(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.getActiveHabitsUseCase = getActiveHabitsUseCase
        self.getArchivedHabitsUseCase = getArchivedHabitsUseCase
        self.getGlobalStreakUseCase = getGlobalStreakUseCase
        self.toggleHabitCompletionUseCase = toggleHabitCompletionUseCase
        self.archiveHabitUseCase = archiveHabitUseCase
        self.unarchiveHabitUseCase = unarchiveHabitUseCase
        self.deleteHabitUseCase = deleteHabitUseCase
        self.habitReminderScheduler = habitReminderScheduler
        self.routineWidgetRefresher = routineWidgetRefresher
        self.premiumGate = premiumGate
        self.analytics = analytics
        self.clock = clock
        self.uiState.maxHabits = premiumGate.maxActiveHabits
    }

    func onAppear() {
        if !didTrackOpen {
            didTrackOpen = true
            analytics.trackTabOpened()
        }
        Task {
            await load()
            // Coming back to the list is also the moment to re-sync the widgets: a habit may have
            // been changed on the detail screen, or the day may simply have rolled over.
            await routineWidgetRefresher.refresh()
        }
    }

    func onFilterChanged(_ filter: RoutineFilter) {
        guard uiState.filter != filter else { return }
        uiState.filter = filter
        Task { await load() }
    }

    /// Android's `onToggleDay` from the list: `habit_completed` only when the day ends up marked,
    /// then the streak comparison. Android only tracks streak events here, never from the detail
    /// screen — mirrored so both platforms count milestones the same way (see `PARITY.md`).
    func onToggleToday(_ habitId: String) {
        let now = clock()
        let previousStreak = uiState.habits.first { $0.id == habitId }?.streak.current ?? 0
        Task {
            do {
                let completed = try await toggleHabitCompletionUseCase.execute(habitId: habitId, date: now, today: now)
                if completed {
                    // Always today from the list, so never retroactive — kept explicit for parity.
                    analytics.trackHabitCompleted(habitId: habitId, isRetroactive: false, source: .app)
                }
                await load()
                // Read after `load()` has awaited the store, so it can't race the new state —
                // the reason Android reads the repository instead of its reactive list.
                if let current = uiState.habits.first(where: { $0.id == habitId })?.streak.current {
                    analytics.trackStreakChange(previous: previousStreak, current: current)
                }
                await routineWidgetRefresher.refresh()
            } catch {
                print("[RoutineViewModel] toggleToday error: \(error)")
            }
        }
    }

    func onArchive(_ habitId: String) {
        let habit = uiState.habits.first { $0.id == habitId }?.habit
        Task {
            do {
                try await archiveHabitUseCase.execute(id: habitId)
                await habitReminderScheduler.cancel(habitId: habitId)
                if let habit {
                    analytics.trackHabitArchived(createdAt: habit.createdAt, now: clock())
                }
                await load()
                await routineWidgetRefresher.refresh()
            } catch {
                print("[RoutineViewModel] archive error: \(error)")
            }
        }
    }

    func onUnarchive(_ habitId: String) {
        Task {
            do {
                try await unarchiveHabitUseCase.execute(id: habitId)
                await load()
                await routineWidgetRefresher.refresh()
            } catch {
                print("[RoutineViewModel] unarchive error: \(error)")
            }
        }
    }

    func onDelete(_ habitId: String) {
        Task {
            do {
                try await deleteHabitUseCase.execute(id: habitId)
                await habitReminderScheduler.cancel(habitId: habitId)
                await load()
                await routineWidgetRefresher.refresh()
            } catch {
                print("[RoutineViewModel] delete error: \(error)")
            }
        }
    }

    func reload() {
        Task { await load() }
    }

    private func load() async {
        uiState.isLoading = uiState.habits.isEmpty
        do {
            let today = clock()
            async let activeHabits = getActiveHabitsUseCase.execute(today: today)
            async let streak = getGlobalStreakUseCase.execute(today: today)

            let active = try await activeHabits
            uiState.activeCount = active.count
            uiState.globalStreak = try await streak

            switch uiState.filter {
            case .active:
                uiState.habits = active
            case .archived:
                uiState.habits = try await getArchivedHabitsUseCase.execute(today: today)
            }
        } catch {
            print("[RoutineViewModel] load error: \(error)")
        }
        uiState.maxHabits = premiumGate.maxActiveHabits
        uiState.isLoading = false
    }
}
