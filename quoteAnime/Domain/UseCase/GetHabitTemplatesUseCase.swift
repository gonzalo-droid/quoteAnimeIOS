import Foundation

/// Habit suggestions: the bundled list at once, the remote one when it arrives — Android's
/// `GetHabitTemplatesUseCase` (`492f80f`). Remote templates let a new suggestion ship without a
/// release; the bundled list keeps the editor usable offline and on first launch.
///
/// Same fallback as Android: an empty or missing `/habitTemplates`, or any failure, gives the
/// bundled list; otherwise the remote list sorted by `order`. iOS also falls back when every
/// remote template was dropped as invalid (see `HabitTemplateDTO`), which Android can't reach.
///
/// Android's editor waits for the remote flow before it has anything to show — offline, with no
/// RTDB cache, that is never, despite its KDoc. iOS shows `bundled` first and replaces it with
/// `execute()`'s result, which is what that KDoc describes.
struct GetHabitTemplatesUseCase {
    private let remote: HabitTemplateRemoteSource?
    private let paletteSize: Int

    /// `remote: nil` is the bundled list only — previews and tests that don't care.
    init(remote: HabitTemplateRemoteSource? = nil, paletteSize: Int = HabitPalette.colors.count) {
        self.remote = remote
        self.paletteSize = paletteSize
    }

    /// What a screen shows before the network answers.
    var bundled: [HabitTemplate] { DefaultHabitTemplates.all }

    func execute() async -> [HabitTemplate] {
        guard let remote else { return bundled }
        do {
            let templates = try await remote.fetchTemplates()
                .compactMap { $0.toDomain(paletteSize: paletteSize) }
            guard !templates.isEmpty else { return bundled }
            // Ties broken by id: the RTDB hands children over in key order, which is the order
            // Android's stable `sortedBy` keeps.
            return templates.sorted { ($0.order, $0.id) < ($1.order, $1.id) }
        } catch {
            print("[GetHabitTemplatesUseCase] remote templates unavailable, using bundled: \(error)")
            return bundled
        }
    }
}
