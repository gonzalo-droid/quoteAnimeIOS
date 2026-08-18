import Foundation
import SwiftData

@available(iOS 17, *)
@Model
final class HabitCompletionModel {
    var habitId: String
    /// Always start-of-day — completions are per calendar day, never per timestamp.
    var date: Date

    init(habitId: String, date: Date) {
        self.habitId = habitId
        self.date = date
    }
}
