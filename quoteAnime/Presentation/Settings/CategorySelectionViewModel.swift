import Foundation
import Combine

/// Backs the anime selection screen. Mirrors Android's `SettingsViewModel.onCategoryToggled` /
/// `onSelectAllCategories`: every change is persisted immediately and reschedules the quote
/// notifications, instead of waiting for a "save" action the user never gets.
///
/// Semantics copied from Android: **an empty set means "all animes"**, so clearing the last
/// selected anime is the same as choosing "Todos".
@MainActor
final class CategorySelectionViewModel: ObservableObject {
    @Published private(set) var categories: [Category] = []
    @Published private(set) var selectedIds: Set<String> = []
    @Published private(set) var isLoading = true
    @Published private(set) var loadFailed = false

    private let getCategories: GetCategoriesUseCase
    private let getUserPreferences: GetUserPreferencesUseCase
    private let updateUserPreferences: UpdateUserPreferencesUseCase
    private let rescheduleNotifications: RescheduleQuoteNotificationsUseCase

    init(
        getCategories: GetCategoriesUseCase,
        getUserPreferences: GetUserPreferencesUseCase,
        updateUserPreferences: UpdateUserPreferencesUseCase,
        rescheduleNotifications: RescheduleQuoteNotificationsUseCase
    ) {
        self.getCategories = getCategories
        self.getUserPreferences = getUserPreferences
        self.updateUserPreferences = updateUserPreferences
        self.rescheduleNotifications = rescheduleNotifications
    }

    var allSelected: Bool { selectedIds.isEmpty }

    func load() async {
        selectedIds = getUserPreferences.execute().selectedCategoryIds
        guard categories.isEmpty else { isLoading = false; return }
        isLoading = true
        loadFailed = false
        do {
            categories = try await getCategories.execute()
        } catch {
            loadFailed = true
            print("[CategorySelectionViewModel] load failed: \(error)")
        }
        isLoading = false
    }

    func isSelected(_ id: String) -> Bool { selectedIds.contains(id) }

    func toggle(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
        persist()
    }

    func selectAll() {
        guard !selectedIds.isEmpty else { return }
        selectedIds = []
        persist()
    }

    private func persist() {
        var prefs = getUserPreferences.execute()
        prefs.selectedCategoryIds = selectedIds
        updateUserPreferences.execute(prefs)
        Task { await rescheduleNotifications.execute(preferences: prefs) }
    }
}
