import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var selectedTemplateId: String?

    let habitTemplates = DefaultHabitTemplates.all.filter { !$0.isPremiumOnly }

    private var setOnboardingCompleted: SetOnboardingCompletedUseCase?
    /// Nil below iOS 17. When it is nil the habit page is not offered at all — see
    /// `OnboardingView(isHabitSelectionAvailable:)` — so no habit can be silently dropped here.
    private var createHabitUseCase: CreateHabitUseCase?
    private var onComplete: (() -> Void)?

    private var setupDone = false

    func setup(
        setOnboardingCompleted: SetOnboardingCompletedUseCase,
        createHabitUseCase: CreateHabitUseCase?,
        onComplete: @escaping () -> Void
    ) {
        guard !setupDone else { return }
        setupDone = true
        self.setOnboardingCompleted = setOnboardingCompleted
        self.createHabitUseCase     = createHabitUseCase
        self.onComplete             = onComplete
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
                    description: nil,
                    iconKey: template.iconKey,
                    colorIndex: template.themeColorIndex ?? 0,
                    startDate: Date(),
                    templateId: template.id,
                    coverAnimeSlug: nil,
                    createdAt: Date()
                )
                _ = try? await createHabitUseCase.execute(habit)
                onComplete?()
            }
        } else {
            onComplete?()
        }
    }
}
