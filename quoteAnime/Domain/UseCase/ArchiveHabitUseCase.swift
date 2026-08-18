import Foundation

struct ArchiveHabitUseCase {
    private let repository: HabitRepository

    init(repository: HabitRepository) {
        self.repository = repository
    }

    func execute(id: String) async throws {
        try await repository.archiveHabit(id: id)
    }
}
