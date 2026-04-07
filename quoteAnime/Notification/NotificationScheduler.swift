import Foundation
import UserNotifications

final class NotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional:
            return true
        default:
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    /// Cancels all pending notifications and reschedules based on `preferences` and `quotes`.
    func reschedule(preferences: UserPreferences, quotes: [Quote]) async {
        await center.removeAllPendingNotificationRequests()

        guard preferences.notificationsEnabled, !quotes.isEmpty else { return }

        let frequency  = max(1, preferences.notificationFrequency)
        let startHour  = preferences.notificationStartHour
        let endHour    = preferences.notificationEndHour
        let totalRange = max(1, endHour - startHour)
        let intervalMinutes = (totalRange * 60) / frequency

        var requests: [UNNotificationRequest] = []
        for slot in 0..<min(frequency, 64) {
            let totalOffset = slot * intervalMinutes
            let hour   = startHour + totalOffset / 60
            let minute = totalOffset % 60
            guard hour < endHour else { break }

            let quote   = quotes[slot % quotes.count]
            let content = NotificationHelper.makeContent(for: quote)

            var components = DateComponents()
            components.hour   = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "quote_notification_\(slot)",
                content: content,
                trigger: trigger
            )
            requests.append(request)
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    func cancelAll() async {
        await center.removeAllPendingNotificationRequests()
    }
}
