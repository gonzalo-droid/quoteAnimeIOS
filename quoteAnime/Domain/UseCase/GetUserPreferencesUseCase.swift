import Foundation

struct GetUserPreferencesUseCase {
    private let repository: UserPreferencesRepository

    init(repository: UserPreferencesRepository) {
        self.repository = repository
    }

    func execute() -> UserPreferences {
        repository.getPreferences()
    }
}
