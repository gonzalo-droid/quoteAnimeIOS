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
    private let premiumGate: PremiumGate

    init(
        getActiveHabitsUseCase: GetActiveHabitsUseCase,
        getArchivedHabitsUseCase: GetArchivedHabitsUseCase,
        getGlobalStreakUseCase: GetGlobalStreakUseCase,
        toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase,
        archiveHabitUseCase: ArchiveHabitUseCase,
        unarchiveHabitUseCase: UnarchiveHabitUseCase,
        deleteHabitUseCase: DeleteHabitUseCase,
        premiumGate: PremiumGate
    ) {
        self.getActiveHabitsUseCase = getActiveHabitsUseCase
        self.getArchivedHabitsUseCase = getArchivedHabitsUseCase
        self.getGlobalStreakUseCase = getGlobalStreakUseCase
        self.toggleHabitCompletionUseCase = toggleHabitCompletionUseCase
        self.archiveHabitUseCase = archiveHabitUseCase
        self.unarchiveHabitUseCase = unarchiveHabitUseCase
        self.deleteHabitUseCase = deleteHabitUseCase
        self.premiumGate = premiumGate
        self.uiState.maxHabits = premiumGate.maxActiveHabits
    }

    func onAppear() {
        Task { await load() }
    }

    func onFilterChanged(_ filter: RoutineFilter) {
        guard uiState.filter != filter else { return }
        uiState.filter = filter
        Task { await load() }
    }

    func onToggleToday(_ habitId: String) {
        Task {
            do {
                try await toggleHabitCompletionUseCase.execute(habitId: habitId, date: Date())
                await load()
            } catch {
                print("[RoutineViewModel] toggleToday error: \(error)")
            }
        }
    }

    func onArchive(_ habitId: String) {
        Task {
            do {
                try await archiveHabitUseCase.execute(id: habitId)
                await load()
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
            } catch {
                print("[RoutineViewModel] unarchive error: \(error)")
            }
        }
    }

    func onDelete(_ habitId: String) {
        Task {
            do {
                try await deleteHabitUseCase.execute(id: habitId)
                await load()
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
            async let activeHabits = getActiveHabitsUseCase.execute()
            async let streak = getGlobalStreakUseCase.execute()

            let active = try await activeHabits
            uiState.activeCount = active.count
            uiState.globalStreak = try await streak

            switch uiState.filter {
            case .active:
                uiState.habits = active
            case .archived:
                uiState.habits = try await getArchivedHabitsUseCase.execute()
            }
        } catch {
            print("[RoutineViewModel] load error: \(error)")
        }
        uiState.maxHabits = premiumGate.maxActiveHabits
        uiState.isLoading = false
    }
}
