import Foundation

protocol UserPreferencesRepository {
    func getPreferences() -> UserPreferences
    func savePreferences(_ preferences: UserPreferences)
    func isOnboardingCompleted() -> Bool
    func setOnboardingCompleted(_ completed: Bool)
}
