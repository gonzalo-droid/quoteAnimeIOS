import Foundation

/// Bundled-only for now — no Firestore/Firebase override yet, unlike Android's remote
/// `HabitTemplateDto` source. Revisit once templates need to be updated without a release.
struct GetHabitTemplatesUseCase {
    func execute() -> [HabitTemplate] {
        DefaultHabitTemplates.all
    }
}
