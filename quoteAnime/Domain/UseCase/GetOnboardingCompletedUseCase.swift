import Foundation

struct GetOnboardingCompletedUseCase {
    private let repository: UserPreferencesRepository

    init(repository: UserPreferencesRepository) {
        self.repository = repository
    }

    func execute() -> Bool {
        repository.isOnboardingCompleted()
    }
}
