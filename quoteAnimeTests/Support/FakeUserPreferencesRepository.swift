import Foundation
@testable import quoteAnime

/// In-memory `UserPreferencesRepository`, so preference-driven flows can be tested without
/// touching `UserDefaults`. The round-trip of the real store is covered separately by
/// `UserPreferencesStoreTests`.
final class FakeUserPreferencesRepository: UserPreferencesRepository {

    private(set) var preferences: UserPreferences
    private(set) var onboardingCompleted: Bool
    private(set) var saveCount = 0
    private(set) var onboardingWrites: [Bool] = []

    init(preferences: UserPreferences = UserPreferences(), onboardingCompleted: Bool = false) {
        self.preferences = preferences
        self.onboardingCompleted = onboardingCompleted
    }

    func getPreferences() -> UserPreferences { preferences }

    func savePreferences(_ preferences: UserPreferences) {
        self.preferences = preferences
        saveCount += 1
    }

    func isOnboardingCompleted() -> Bool { onboardingCompleted }

    func setOnboardingCompleted(_ completed: Bool) {
        onboardingCompleted = completed
        onboardingWrites.append(completed)
    }
}
