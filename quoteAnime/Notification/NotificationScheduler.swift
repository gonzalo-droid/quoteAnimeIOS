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

    /// Cancels all pending notifications and schedules up to 64 future ones,
    /// each with a **different** randomly selected quote.
    ///
    /// iOS limits apps to 64 pending notifications at a time. With that budget:
    /// - frequency 1/day  → ~64 days of notifications
    /// - frequency 5/day  → ~12 days
    /// - frequency 10/day →  ~6 days
    ///
    /// Call this method again when the app returns to the foreground to refill the budget.
    func reschedule(preferences: UserPreferences, quotes: [Quote]) async {
        await center.removeAllPendingNotificationRequests()
        guard preferences.notificationsEnabled, !quotes.isEmpty else { return }

        let frequency = max(1, preferences.notificationFrequency)

        // Work entirely in minutes-from-midnight to correctly handle start/end minutes
        let startTotal = preferences.notificationStartHour * 60 + preferences.notificationStartMinute
        let endTotal   = preferences.notificationEndHour   * 60 + preferences.notificationEndMinute
        let rangeTotal = endTotal - startTotal

        guard rangeTotal > 0 else {
            print("[NotificationScheduler] invalid time range (start >= end), nothing scheduled")
            return
        }

        // Distribute exactly `frequency` slots evenly across the range.
        // Each slot = startTotal + n * interval, kept strictly inside [startTotal, endTotal).
        let intervalMins = max(1, rangeTotal / frequency)
        let slots: [(hour: Int, minute: Int)] = (0..<frequency).compactMap { n in
            let absoluteMin = startTotal + n * intervalMins
            guard absoluteMin < endTotal else { return nil }
            return (absoluteMin / 60, absoluteMin % 60)
        }
        guard !slots.isEmpty else { return }

        // Shuffled quote pool — cycles with a new shuffle when exhausted
        var pool = quotes.shuffled()
        var poolIdx = 0
        func nextQuote() -> Quote {
            if poolIdx >= pool.count { pool = quotes.shuffled(); poolIdx = 0 }
            defer { poolIdx += 1 }
            return pool[poolIdx]
        }

        let calendar = Calendar.current
        let now = Date()
        var requests: [UNNotificationRequest] = []

        outer: for dayOffset in 0..<90 {               // never exceed 90 days ahead
            guard let base = calendar.date(byAdding: .day, value: dayOffset, to: now) else { break }
            for slot in slots {
                guard requests.count < 64 else { break outer }  // iOS hard limit

                guard
                    let fireDate = calendar.date(
                        bySettingHour: slot.hour, minute: slot.minute, second: 0, of: base
                    ),
                    fireDate > now                              // skip times already past
                else { continue }

                let comps   = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let content = NotificationHelper.makeContent(for: nextQuote())
                let request = UNNotificationRequest(
                    identifier: "quote_\(dayOffset)_\(slot.hour)h\(slot.minute)m",
                    content: content,
                    trigger: trigger
                )
                requests.append(request)
            }
        }

        for request in requests {
            try? await center.add(request)
        }

        print("[NotificationScheduler] scheduled \(requests.count) notifications " +
              "(\(frequency)/day, \(slots.count) slots, pool of \(quotes.count) quotes)")
    }

    func cancelAll() async {
        await center.removeAllPendingNotificationRequests()
    }
}
