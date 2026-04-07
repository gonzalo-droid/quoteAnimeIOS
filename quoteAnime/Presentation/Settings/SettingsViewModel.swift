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
    private let notificationScheduler: NotificationScheduler
    private let getRandomQuote: GetRandomQuoteUseCase
    private var setupDone = false

    init(
        getUserPreferences: GetUserPreferencesUseCase,
        updateUserPreferences: UpdateUserPreferencesUseCase,
        notificationScheduler: NotificationScheduler,
        getRandomQuote: GetRandomQuoteUseCase
    ) {
        self.getUserPreferences    = getUserPreferences
        self.updateUserPreferences = updateUserPreferences
        self.notificationScheduler = notificationScheduler
        self.getRandomQuote        = getRandomQuote
    }

    func onAppear() {
        preferences = getUserPreferences.execute()
        Task { permissionStatus = await notificationScheduler.authorizationStatus() }
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
        guard let quote = try? await getRandomQuote.execute() else { return }
        // Provide a variety of quotes by using a singleton quote for now;
        // A full implementation would cache all quotes and sample from them.
        await notificationScheduler.reschedule(preferences: preferences, quotes: [quote])
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
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
