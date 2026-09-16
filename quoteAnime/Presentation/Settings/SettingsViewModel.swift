import Foundation
import Combine
import UserNotifications

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var preferences: UserPreferences = UserPreferences()
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    @Published var showPermissionAlert = false

    private let getUserPreferences: GetUserPreferencesUseCase
    private let updateUserPreferences: UpdateUserPreferencesUseCase
    private let notificationScheduler: QuoteNotificationScheduling
    private let getAllQuotes: GetAllQuotesUseCase
    private let rescheduleNotifications: RescheduleQuoteNotificationsUseCase
    private var setupDone = false

    init(
        getUserPreferences: GetUserPreferencesUseCase,
        updateUserPreferences: UpdateUserPreferencesUseCase,
        notificationScheduler: QuoteNotificationScheduling,
        getAllQuotes: GetAllQuotesUseCase,
        rescheduleNotifications: RescheduleQuoteNotificationsUseCase
    ) {
        self.getUserPreferences    = getUserPreferences
        self.updateUserPreferences = updateUserPreferences
        self.notificationScheduler = notificationScheduler
        self.getAllQuotes           = getAllQuotes
        self.rescheduleNotifications = rescheduleNotifications
    }

    /// Re-read on every appearance — the anime selection screen writes straight to the store,
    /// so coming back from it has to pick the new selection up for the summary row.
    func onAppear() {
        preferences = getUserPreferences.execute()
        Task { permissionStatus = await notificationScheduler.authorizationStatus() }
    }

    // MARK: - Anime selection

    /// Detail text for the row that opens the anime selection. Empty set means "all animes",
    /// exactly as on Android (`SettingsUiState.allCategoriesSelected`).
    var categorySelectionSummary: String {
        switch preferences.selectedCategoryIds.count {
        case 0:  return "Todos"
        case 1:  return "1 anime"
        case let count: return "\(count) animes"
        }
    }

    // MARK: - Notifications

    func toggleNotifications() async {
        if preferences.notificationsEnabled {
            // User is turning it ON
            let granted = await notificationScheduler.requestPermission()
            if granted {
                await reschedule()
            } else {
                permissionStatus = await notificationScheduler.authorizationStatus()
                if permissionStatus == .denied {
                    showPermissionAlert = true
                }
                preferences.notificationsEnabled = false
            }
        } else {
            // User is turning it OFF
            await notificationScheduler.cancelAll()
        }
        savePreferences()
    }

    func savePreferences() {
        updateUserPreferences.execute(preferences)
        if preferences.notificationsEnabled {
            Task { await reschedule() }
        }
    }

    private func reschedule() async {
        await rescheduleNotifications.execute(preferences: preferences)
    }

    // MARK: - Test notifications

    @Published var testNotificationMessage: String? = nil

    /// Schedules `count` notifications firing 5 s apart, each with a different quote.
    /// Removes them after 60 s so they don't pollute the real schedule.
    func scheduleTestNotifications(count: Int = 3) async {
        let status = await notificationScheduler.authorizationStatus()
        guard status == .authorized || status == .provisional else {
            testNotificationMessage = "Activa los permisos de notificaciones primero."
            return
        }

        // Same pool the real schedule uses, so a test notification shows what the user picked.
        guard let quotes = try? await getAllQuotes.execute(filteredBy: preferences.selectedCategoryIds),
              !quotes.isEmpty else {
            testNotificationMessage = "No hay frases disponibles."
            return
        }

        let center = UNUserNotificationCenter.current()

        // Remove previous test notifications
        let testIDs = (0..<count).map { "test_notification_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: testIDs)

        var shuffled = quotes.shuffled()
        for i in 0..<count {
            let quote   = shuffled[i % shuffled.count]
            let content = NotificationHelper.makeContent(for: quote)
            content.subtitle = "(\(i + 1)/\(count)) " + content.subtitle

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: Double((i + 1) * 5),   // 5 s, 10 s, 15 s …
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: testIDs[i],
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }

        testNotificationMessage = "\(count) notificaciones de prueba en \(count * 5) segundos."
    }

    // MARK: - DatePicker bindings

    var notificationStartDate: Date {
        get { dateFrom(hour: preferences.notificationStartHour, minute: preferences.notificationStartMinute) }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            preferences.notificationStartHour   = c.hour   ?? 8
            preferences.notificationStartMinute = c.minute ?? 0
        }
    }

    var notificationEndDate: Date {
        get { dateFrom(hour: preferences.notificationEndHour, minute: preferences.notificationEndMinute) }
        set {
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            preferences.notificationEndHour   = c.hour   ?? 22
            preferences.notificationEndMinute = c.minute ?? 0
        }
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour   = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - App Version

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
