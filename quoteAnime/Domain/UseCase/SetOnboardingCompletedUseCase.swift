import Foundation

struct SetOnboardingCompletedUseCase {
    private let repository: UserPreferencesRepository

    init(repository: UserPreferencesRepository) {
        self.repository = repository
    }

    func execute(_ completed: Bool) {
        repository.setOnboardingCompleted(completed)
    }
}
