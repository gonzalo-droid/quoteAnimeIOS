import Foundation

protocol HabitRepository {
    func fetchActiveHabits() async throws -> [Habit]
    func fetchArchivedHabits() async throws -> [Habit]
    func fetchCompletions(habitId: String) async throws -> [Date]
    /// Dates where at least one habit was completed — feeds the global streak.
    func fetchAllCompletionDates() async throws -> [Date]
    func countActiveHabits() async throws -> Int
    func fetchHabit(id: String) async throws -> Habit?
    func saveHabit(_ habit: Habit) async throws
    func setCompletion(habitId: String, date: Date, completed: Bool) async throws
    func isCompleted(habitId: String, date: Date) async throws -> Bool
    func archiveHabit(id: String) async throws
    func unarchiveHabit(id: String) async throws
    /// Permanent delete — cascades to that habit's completions.
    func deleteHabit(id: String) async throws
}
