import Foundation

enum CreateHabitError: Error {
    case habitLimitReached
}

/// Enforces the free-tier active-habit cap before insert — mirrors Android's
/// `CreateHabitUseCase`, which is the single gate point for `PremiumGate.maxActiveHabits`.
struct CreateHabitUseCase {
    private let repository: HabitRepository
    private let premiumGate: PremiumGate

    init(repository: HabitRepository, premiumGate: PremiumGate) {
        self.repository = repository
        self.premiumGate = premiumGate
    }

    func execute(_ habit: Habit) async throws {
        let activeCount = try await repository.countActiveHabits()
        guard activeCount < premiumGate.maxActiveHabits else {
            throw CreateHabitError.habitLimitReached
        }
        try await repository.saveHabit(habit)
    }
}
