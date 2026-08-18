import Foundation

/// Always derived from completion dates, never persisted directly — matches the Android
/// model, so it can't drift when timezone changes or a past day is marked retroactively.
struct StreakState: Hashable {
    var current: Int = 0
    var best: Int = 0
    var lastCompletedDate: Date? = nil
    var completedToday: Bool = false
}
