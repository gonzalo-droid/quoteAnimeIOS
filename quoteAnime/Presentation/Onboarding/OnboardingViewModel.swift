import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var selectedCategoryIds: Set<String> = []
    @Published var currentPage: Int = 0
    @Published var isLoading = false

    private var getCategoriesUseCase: GetCategoriesUseCase?
    private var setOnboardingCompleted: SetOnboardingCompletedUseCase?
    private var updateUserPreferences: UpdateUserPreferencesUseCase?
    private var getUserPreferences: GetUserPreferencesUseCase?
    private var onComplete: (() -> Void)?

    private var setupDone = false

    func setup(
        getCategoriesUseCase: GetCategoriesUseCase,
        setOnboardingCompleted: SetOnboardingCompletedUseCase,
        updateUserPreferences: UpdateUserPreferencesUseCase,
        getUserPreferences: GetUserPreferencesUseCase,
        onComplete: @escaping () -> Void
    ) {
        guard !setupDone else { return }
        setupDone = true
        self.getCategoriesUseCase  = getCategoriesUseCase
        self.setOnboardingCompleted = setOnboardingCompleted
        self.updateUserPreferences  = updateUserPreferences
        self.getUserPreferences     = getUserPreferences
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

    func complete() {
        var prefs = getUserPreferences?.execute() ?? UserPreferences()
        prefs.selectedCategoryIds = selectedCategoryIds
        updateUserPreferences?.execute(prefs)
        setOnboardingCompleted?.execute(true)
        onComplete?()
    }
}
