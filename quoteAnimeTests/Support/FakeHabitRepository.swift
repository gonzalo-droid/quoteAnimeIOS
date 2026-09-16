import Foundation
@testable import quoteAnime

/// Hand-written stand-in for `HabitRepository`. Mirrors the two behaviours of `HabitDAO`
/// the domain layer actually depends on: completions are keyed by `startOfDay`, and
/// `countActiveHabits` excludes archived habits.
final class FakeHabitRepository: HabitRepository {

    /// Habits keyed by id, in insertion order.
    private(set) var habits: [Habit] = []
    private(set) var archivedIds: Set<String> = []
    /// habitId -> set of normalised (start-of-day) completion dates.
    private(set) var completions: [String: Set<Date>] = [:]

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: Seeding helpers (test-side only)

    func seed(habits newHabits: [Habit], archived: Set<String> = []) {
        habits = newHabits
        archivedIds = archived
    }

    func seedCompletions(habitId: String, dates: [Date]) {
        completions[habitId, default: []].formUnion(dates.map { calendar.startOfDay(for: $0) })
    }

    func completionCount(habitId: String) -> Int {
        completions[habitId]?.count ?? 0
    }

    // MARK: HabitRepository

    func fetchActiveHabits() async throws -> [Habit] {
        habits.filter { !archivedIds.contains($0.id) }
    }

    func fetchArchivedHabits() async throws -> [Habit] {
        habits.filter { archivedIds.contains($0.id) }
    }

    func fetchCompletions(habitId: String) async throws -> [Date] {
        Array(completions[habitId] ?? [])
    }

    func fetchAllCompletionDates() async throws -> [Date] {
        completions.values.flatMap { $0 }
    }

    func countActiveHabits() async throws -> Int {
        habits.filter { !archivedIds.contains($0.id) }.count
    }

    func fetchHabit(id: String) async throws -> Habit? {
        habits.first { $0.id == id }
    }

    func saveHabit(_ habit: Habit) async throws {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
        } else {
            habits.append(habit)
        }
    }

    func setCompletion(habitId: String, date: Date, completed: Bool) async throws {
        let day = calendar.startOfDay(for: date)
        if completed {
            completions[habitId, default: []].insert(day)
        } else {
            completions[habitId]?.remove(day)
        }
    }

    func isCompleted(habitId: String, date: Date) async throws -> Bool {
        completions[habitId]?.contains(calendar.startOfDay(for: date)) ?? false
    }

    func archiveHabit(id: String) async throws {
        archivedIds.insert(id)
    }

    func unarchiveHabit(id: String) async throws {
        archivedIds.remove(id)
    }

    func deleteHabit(id: String) async throws {
        habits.removeAll { $0.id == id }
        completions[id] = nil
        archivedIds.remove(id)
    }
}
