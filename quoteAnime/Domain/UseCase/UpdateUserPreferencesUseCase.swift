import Foundation

struct UpdateUserPreferencesUseCase {
    private let repository: UserPreferencesRepository

    init(repository: UserPreferencesRepository) {
        self.repository = repository
    }

    func execute(_ preferences: UserPreferences) {
        repository.savePreferences(preferences)
    }
}
