import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var selectedCategoryIds: Set<String> = []
    @Published var currentPage: Int = 0
    @Published var isLoading = false
    @Published var selectedTemplateId: String?

    let habitTemplates = DefaultHabitTemplates.all.filter { !$0.isPremiumOnly }

    private var getCategoriesUseCase: GetCategoriesUseCase?
    private var setOnboardingCompleted: SetOnboardingCompletedUseCase?
    private var updateUserPreferences: UpdateUserPreferencesUseCase?
    private var getUserPreferences: GetUserPreferencesUseCase?
    /// Nil below iOS 17 — habit creation is simply skipped, quote preferences still save.
    private var createHabitUseCase: CreateHabitUseCase?
    private var onComplete: (() -> Void)?

    private var setupDone = false

    func setup(
        getCategoriesUseCase: GetCategoriesUseCase,
        setOnboardingCompleted: SetOnboardingCompletedUseCase,
        updateUserPreferences: UpdateUserPreferencesUseCase,
        getUserPreferences: GetUserPreferencesUseCase,
        createHabitUseCase: CreateHabitUseCase?,
        onComplete: @escaping () -> Void
    ) {
        guard !setupDone else { return }
        setupDone = true
        self.getCategoriesUseCase  = getCategoriesUseCase
        self.setOnboardingCompleted = setOnboardingCompleted
        self.updateUserPreferences  = updateUserPreferences
        self.getUserPreferences     = getUserPreferences
        self.createHabitUseCase     = createHabitUseCase
        self.onComplete             = onComplete
        Task { await loadCategories() }
    }

    private func loadCategories() async {
        isLoading = true
        do {
            categories = try await getCategoriesUseCase!.execute()
        } catch {
            print("[OnboardingViewModel] \(error)")
        }
        isLoading = false
    }

    func toggleCategory(_ id: String) {
        if selectedCategoryIds.contains(id) {
            selectedCategoryIds.remove(id)
        } else {
            selectedCategoryIds.insert(id)
        }
    }

    func selectTemplate(_ id: String) {
        selectedTemplateId = (selectedTemplateId == id) ? nil : id
    }

    func complete() {
        var prefs = getUserPreferences?.execute() ?? UserPreferences()
        prefs.selectedCategoryIds = selectedCategoryIds
        updateUserPreferences?.execute(prefs)
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
                try? await createHabitUseCase.execute(habit)
                onComplete?()
            }
        } else {
            onComplete?()
        }
    }
}
