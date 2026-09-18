import Foundation
@testable import quoteAnime

/// Stands in for `/habitTemplates`: returns what it was given, or throws.
final class FakeHabitTemplateRemoteSource: HabitTemplateRemoteSource {
    struct Offline: Error {}

    var result: Result<[HabitTemplateDTO], Error>
    private(set) var fetchCount = 0

    init(_ templates: [HabitTemplateDTO]) { result = .success(templates) }
    init(error: Error = Offline()) { result = .failure(error) }

    func fetchTemplates() async throws -> [HabitTemplateDTO] {
        fetchCount += 1
        return try result.get()
    }
}
