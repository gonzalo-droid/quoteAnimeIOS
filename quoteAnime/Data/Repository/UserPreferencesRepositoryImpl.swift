import Foundation

final class UserPreferencesRepositoryImpl: UserPreferencesRepository {
    private let store: UserPreferencesStore

    init(store: UserPreferencesStore) {
        self.store = store
    }

    func getPreferences() -> UserPreferences {
        store.load()
    }

    func savePreferences(_ preferences: UserPreferences) {
        store.save(preferences)
    }

    func isOnboardingCompleted() -> Bool {
        store.isOnboardingCompleted
    }

    func setOnboardingCompleted(_ completed: Bool) {
        store.isOnboardingCompleted = completed
    }
}
