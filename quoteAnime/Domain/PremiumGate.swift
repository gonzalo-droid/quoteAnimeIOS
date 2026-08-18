import Foundation

/// Single place plan-based limits live — hardcoded to free until real subscriptions exist
/// on iOS. Mirrors the same day-1 stub the Android app started with, before its Premium
/// paywall existed: flipping `isPremium` later shouldn't require touching use cases or UI.
struct PremiumGate {
    static let freeHabitLimit = 3

    var isPremium: Bool = false

    var maxActiveHabits: Int {
        isPremium ? Int.max : Self.freeHabitLimit
    }
}
