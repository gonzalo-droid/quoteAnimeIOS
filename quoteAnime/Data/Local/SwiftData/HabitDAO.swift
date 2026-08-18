import Foundation
import SwiftData

/// SwiftData-backed `HabitRepository`. iOS 17+ only — unlike favorites, habits have no
/// UserDefaults fallback for iOS 16 (dropped to keep the initial port scoped; `AppDependencies`
/// leaves `habitRepository` nil below iOS 17, and "Mi Rutina" is hidden from the tab bar there).
@available(iOS 17, *)
final class HabitDAO: HabitRepository {
    private let context: ModelContext

    init(modelContext: ModelContext) {
        self.context = modelContext
    }

    func fetchActiveHabits() async throws -> [Habit] {
        let descriptor = FetchDescriptor<HabitModel>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func fetchCompletions(habitId: String) async throws -> [Date] {
        let descriptor = FetchDescriptor<HabitCompletionModel>(
            predicate: #Predicate { $0.habitId == habitId }
        )
        return try context.fetch(descriptor).map { $0.date }
    }

    func fetchAllCompletionDates() async throws -> [Date] {
        let descriptor = FetchDescriptor<HabitCompletionModel>()
        return try context.fetch(descriptor).map { $0.date }
    }

    func countActiveHabits() async throws -> Int {
        let descriptor = FetchDescriptor<HabitModel>(
            predicate: #Predicate { !$0.isArchived }
        )
        return try context.fetchCount(descriptor)
    }

    func fetchHabit(id: String) async throws -> Habit? {
        let descriptor = FetchDescriptor<HabitModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first?.toDomain()
    }

    func saveHabit(_ habit: Habit) async throws {
        let habitId = habit.id
        let descriptor = FetchDescriptor<HabitModel>(
            predicate: #Predicate { $0.id == habitId }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.apply(habit)
        } else {
            context.insert(HabitModel(from: habit))
        }
        try context.save()
    }

    func setCompletion(habitId: String, date: Date, completed: Bool) async throws {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<HabitCompletionModel>(
            predicate: #Predicate { $0.habitId == habitId && $0.date == day }
        )
        let existing = try context.fetch(descriptor).first

        if completed {
            if existing == nil {
                context.insert(HabitCompletionModel(habitId: habitId, date: day))
            }
        } else if let existing {
            context.delete(existing)
        }
        try context.save()
    }

    func isCompleted(habitId: String, date: Date) async throws -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<HabitCompletionModel>(
            predicate: #Predicate { $0.habitId == habitId && $0.date == day }
        )
        return try context.fetchCount(descriptor) > 0
    }
}
