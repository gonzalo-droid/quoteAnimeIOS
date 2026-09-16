import Foundation
@testable import quoteAnime

/// Hand-written stand-in for `HabitRepository`. Mirrors the behaviours of `HabitDAO` the
/// domain layer actually depends on: completions are keyed by `startOfDay`,
/// `countActiveHabits` excludes archived habits, and `saveHabit` upserts the whole habit —
/// `isArchived` included — exactly like `HabitModel.apply`.
final class FakeHabitRepository: HabitRepository {

    /// Habits keyed by id, in insertion order. Archive state lives on the habit itself, the
    /// same single source of truth the SwiftData model uses.
    private(set) var habits: [Habit] = []
    /// habitId -> set of normalised (start-of-day) completion dates.
    private(set) var completions: [String: Set<Date>] = [:]

    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    var archivedIds: Set<String> { Set(habits.filter(\.isArchived).map(\.id)) }

    // MARK: Seeding helpers (test-side only)

    func seed(habits newHabits: [Habit], archived: Set<String> = []) {
        habits = newHabits.map { habit in
            var copy = habit
            if archived.contains(habit.id) { copy.isArchived = true }
            return copy
        }
    }

    func seedCompletions(habitId: String, dates: [Date]) {
        completions[habitId, default: []].formUnion(dates.map { calendar.startOfDay(for: $0) })
    }

    func completionCount(habitId: String) -> Int {
        completions[habitId]?.count ?? 0
    }

    // MARK: HabitRepository

    func fetchActiveHabits() async throws -> [Habit] {
        habits.filter { !$0.isArchived }
    }

    func fetchArchivedHabits() async throws -> [Habit] {
        habits.filter(\.isArchived)
    }

    func fetchCompletions(habitId: String) async throws -> [Date] {
        Array(completions[habitId] ?? [])
    }

    func fetchAllCompletionDates() async throws -> [Date] {
        completions.values.flatMap { $0 }
    }

    func countActiveHabits() async throws -> Int {
        habits.filter { !$0.isArchived }.count
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
        setArchived(id: id, isArchived: true)
    }

    func unarchiveHabit(id: String) async throws {
        setArchived(id: id, isArchived: false)
    }

    func deleteHabit(id: String) async throws {
        habits.removeAll { $0.id == id }
        completions[id] = nil
    }

    private func setArchived(id: String, isArchived: Bool) {
        guard let index = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[index].isArchived = isArchived
    }
}
