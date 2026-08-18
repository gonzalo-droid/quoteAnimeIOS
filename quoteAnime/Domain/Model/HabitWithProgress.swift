import Foundation

struct HabitWithProgress: Identifiable, Hashable {
    let habit: Habit
    var completions: Set<Date>
    var streak: StreakState

    var id: String { habit.id }
}
