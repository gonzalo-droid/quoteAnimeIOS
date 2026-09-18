import Foundation
import FirebaseDatabase

/// Where remote habit suggestions come from. A protocol so the use case can be tested without
/// Firebase.
protocol HabitTemplateRemoteSource {
    func fetchTemplates() async throws -> [HabitTemplateDTO]
}

/// `/habitTemplates` in the **Realtime Database** — Android's `HabitTemplateRemoteDataSource`
/// (`492f80f`). Android keeps a live listener; iOS reads once per screen that offers suggestions,
/// which is all either app does with the value.
///
/// `getData()` rather than `observeSingleEvent`: offline with nothing cached, a listener waits
/// for a connection indefinitely, while `getData()` fails — and the use case then keeps the
/// bundled list, which the screen was already showing.
final class FirebaseHabitTemplateRemoteDataSource: HabitTemplateRemoteSource {
    private let reference = Database.database().reference(withPath: "habitTemplates")

    func fetchTemplates() async throws -> [HabitTemplateDTO] {
        let snapshot = try await reference.getData()
        return HabitTemplateDTO.decodeNode(snapshot.value)
    }
}
