import SwiftUI
import Combine

struct RoutineUiState {
    var habits: [HabitWithProgress] = []
    var globalStreak: StreakState = StreakState()
    var isLoading: Bool = false
    var maxHabits: Int = PremiumGate.freeHabitLimit
    var activeCount: Int { habits.count }
    var canAddHabit: Bool { activeCount < maxHabits }
    var isEmpty: Bool { !isLoading && habits.isEmpty }
}

/// Core-scope ViewModel: active habits only, no archive/delete yet (deferred to a later
/// port phase along with Premium and widgets — see project memory on the iOS port plan).
@MainActor
final class RoutineViewModel: ObservableObject {
    @Published var uiState = RoutineUiState()

    private let getActiveHabitsUseCase: GetActiveHabitsUseCase
    private let getGlobalStreakUseCase: GetGlobalStreakUseCase
    private let toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase
    private let premiumGate: PremiumGate

    init(
        getActiveHabitsUseCase: GetActiveHabitsUseCase,
        getGlobalStreakUseCase: GetGlobalStreakUseCase,
        toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase,
        premiumGate: PremiumGate
    ) {
        self.getActiveHabitsUseCase = getActiveHabitsUseCase
        self.getGlobalStreakUseCase = getGlobalStreakUseCase
        self.toggleHabitCompletionUseCase = toggleHabitCompletionUseCase
        self.premiumGate = premiumGate
        self.uiState.maxHabits = premiumGate.maxActiveHabits
    }

    func onAppear() {
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

    func reload() {
        Task { await load() }
    }

    private func load() async {
        uiState.isLoading = uiState.habits.isEmpty
        do {
            async let habits = getActiveHabitsUseCase.execute()
            async let streak = getGlobalStreakUseCase.execute()
            uiState.habits = try await habits
            uiState.globalStreak = try await streak
        } catch {
            print("[RoutineViewModel] load error: \(error)")
        }
        uiState.maxHabits = premiumGate.maxActiveHabits
        uiState.isLoading = false
    }
}
