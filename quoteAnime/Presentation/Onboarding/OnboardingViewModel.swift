import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var selectedTemplateId: String?

    /// The page's suggestions: bundled at once, `/habitTemplates` once `loadTemplates()` answers.
    /// Premium-only ones are always left out here — see "Plantillas en el onboarding" in
    /// `PARITY.md`, still undecided.
    @Published private(set) var habitTemplates = OnboardingViewModel.offerable(GetHabitTemplatesUseCase().bundled)
    private var getHabitTemplates = GetHabitTemplatesUseCase()

    private var setOnboardingCompleted: SetOnboardingCompletedUseCase?
    /// Nil below iOS 17. When it is nil the habit page is not offered at all — see
    /// `OnboardingView(isHabitSelectionAvailable:)` — so no habit can be silently dropped here.
    private var createHabitUseCase: CreateHabitUseCase?
    /// The first habit can be created here and nowhere else in the session, so the widgets have
    /// to be told about it — otherwise a widget added right after onboarding would find an empty
    /// snapshot and offer no habit to follow.
    private var routineWidgetRefresher: RoutineWidgetRefreshing = NoopRoutineWidgetRefresher()
    private var analytics: RoutineAnalytics = NoopRoutineAnalytics()
    private var onComplete: (() -> Void)?

    private var setupDone = false

    func setup(
        setOnboardingCompleted: SetOnboardingCompletedUseCase,
        createHabitUseCase: CreateHabitUseCase?,
        routineWidgetRefresher: RoutineWidgetRefreshing = NoopRoutineWidgetRefresher(),
        analytics: RoutineAnalytics = NoopRoutineAnalytics(),
        getHabitTemplates: GetHabitTemplatesUseCase = GetHabitTemplatesUseCase(),
        onComplete: @escaping () -> Void
    ) {
        guard !setupDone else { return }
        setupDone = true
        self.setOnboardingCompleted = setOnboardingCompleted
        self.createHabitUseCase     = createHabitUseCase
        self.routineWidgetRefresher = routineWidgetRefresher
        self.analytics              = analytics
        self.getHabitTemplates      = getHabitTemplates
        self.onComplete             = onComplete
    }

    /// Replaces the bundled suggestions with the remote ones. A pick that the remote list no
    /// longer has is cleared — the page starts with nothing selected, and "Comenzar" then finishes
    /// without a habit — rather than creating a habit from a suggestion no longer offered.
    func loadTemplates() async {
        let loaded = Self.offerable(await getHabitTemplates.execute())
        guard loaded != habitTemplates else { return }
        habitTemplates = loaded
        if let selectedTemplateId, !loaded.contains(where: { $0.id == selectedTemplateId }) {
            self.selectedTemplateId = nil
        }
    }

    private static func offerable(_ templates: [HabitTemplate]) -> [HabitTemplate] {
        templates.filter { !$0.isPremiumOnly }
    }

    /// The suggestion whose preview the habit page shows, if any.
    var selectedTemplate: HabitTemplate? {
        habitTemplates.first { $0.id == selectedTemplateId }
    }

    func selectTemplate(_ id: String) {
        selectedTemplateId = (selectedTemplateId == id) ? nil : id
    }

    func complete() {
        setOnboardingCompleted?.execute(true)

        if let templateId = selectedTemplateId,
           let template = habitTemplates.first(where: { $0.id == templateId }),
           let createHabitUseCase {
            Task {
                let habit = Habit(
                    id: UUID().uuidString,
                    title: template.title,
                    // Android's onboarding saves neither the description nor the cover, so a
                    // habit started here looked different from the same suggestion picked in the
                    // editor. iOS saves both — see `PARITY.md`.
                    description: HabitThemeImages.description(for: template.themeKey),
                    iconKey: template.iconKey,
                    colorIndex: template.themeColorIndex ?? 0,
                    startDate: Date(),
                    templateId: template.id,
                    coverAnimeSlug: template.themeKey,
                    createdAt: Date()
                )
                if (try? await createHabitUseCase.execute(habit)) != nil {
                    // Android's onboarding reports the same three `false`s: no reminder or end
                    // date can be set on this page.
                    analytics.trackHabitCreated(templateId: template.id, hasReminder: false, hasEndDate: false)
                }
                await routineWidgetRefresher.refresh()
                onComplete?()
            }
        } else {
            onComplete?()
        }
    }
}
