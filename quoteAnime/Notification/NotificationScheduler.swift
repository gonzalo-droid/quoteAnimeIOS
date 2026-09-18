import Foundation
import UserNotifications
import os

/// What the quote-notification callers actually need from the scheduler. Exists so the
/// domain layer can be exercised with a hand-written fake instead of the real
/// `UNUserNotificationCenter`, which a unit-test target can't drive.
protocol QuoteNotificationScheduling {
    func requestPermission() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func reschedule(preferences: UserPreferences, quotes: [Quote]) async
    /// Cancels the pending quote notifications. Habit reminders are left alone.
    func cancelQuoteNotifications() async
}

extension UNUserNotificationCenter {
    /// Asks only while the user hasn't decided yet; afterwards it just reports the decision,
    /// because iOS never shows the system prompt twice. Shared by the quote and habit schedulers.
    func requestAppAuthorization() async -> Bool {
        switch await notificationSettings().authorizationStatus {
        case .notDetermined:
            return (try? await requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }
}

final class NotificationScheduler: QuoteNotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    /// iOS keeps at most 64 pending local notifications per app — quote notifications **and**
    /// habit reminders together. Past that the system silently drops the latest-firing ones.
    static let systemPendingLimit = 64

    /// Every quote request starts with this; habit reminders start with `habit_`. The format of
    /// the ids before tanda 12 (`quote_<day>_<h>h<m>m`) shares the prefix, so rescheduling
    /// also clears what an older build booked.
    static let identifierPrefix = "quote_"

    private static let logger = Logger(subsystem: "com.gonzadev.quoteAnime", category: "QuoteNotifications")

    // MARK: - Permission

    func requestPermission() async -> Bool {
        await center.requestAppAuthorization()
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    /// Replaces the pending quote notifications with the next slots of the user's window
    /// (`QuoteNotificationSlotCalculator`), each with a different random quote while the pool lasts.
    ///
    /// Android books one slot at a time and chains the next from the worker. iOS runs no code
    /// when a notification fires, so it books as many upcoming slots as the 64-request budget
    /// allows — ~64 days at 1 per day, 6.4 days at 10 per day — in date order, so a high
    /// frequency ends on a partial last day rather than skipping one. Home refills it on every
    /// launch, which is also what moves an existing install off the old spacing.
    ///
    /// Only this app's **quote** requests are touched. Habit reminders share the 64-slot budget,
    /// so the quotes take what is left after them instead of crowding them out.
    func reschedule(preferences: UserPreferences, quotes: [Quote]) async {
        let otherPending = await removePendingQuoteRequests()
        guard preferences.notificationsEnabled, !quotes.isEmpty else { return }

        let calendar = Calendar.current
        let fireDates = QuoteNotificationSlotCalculator.upcomingSlots(
            from: Date(),
            startMinute: preferences.notificationStartMinuteOfDay,
            endMinute: preferences.notificationEndMinuteOfDay,
            timesPerDay: preferences.notificationFrequency,
            limit: Self.quoteBudget(otherPendingCount: otherPending),
            calendar: calendar
        )

        // Shuffled quote pool — cycles with a new shuffle when exhausted
        var pool = quotes.shuffled()
        var poolIdx = 0
        func nextQuote() -> Quote {
            if poolIdx >= pool.count { pool = quotes.shuffled(); poolIdx = 0 }
            defer { poolIdx += 1 }
            return pool[poolIdx]
        }

        for fireDate in fireDates {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: Self.identifier(for: comps),
                content: NotificationHelper.makeContent(for: nextQuote()),
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            try? await center.add(request)
        }

        Self.logger.info("scheduled \(fireDates.count) quote notifications (\(preferences.notificationFrequency)/day, \(otherPending) other pending, pool of \(quotes.count))")
        #if DEBUG
        await logPendingQuoteRequests()
        #endif
    }

    /// Cancels the quote notifications only — never a habit reminder.
    func cancelQuoteNotifications() async {
        await removePendingQuoteRequests()
    }

    // MARK: - Budget

    /// How many quote requests fit beside the `otherPendingCount` requests (habit reminders) that
    /// are already pending. Never negative.
    static func quoteBudget(otherPendingCount: Int) -> Int {
        max(0, systemPendingLimit - otherPendingCount)
    }

    static func isQuoteRequest(identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
    }

    /// `quote_20260725_2200` — one per wall-clock minute, so re-adding the same slot replaces it.
    static func identifier(for comps: DateComponents) -> String {
        String(format: "%@%04d%02d%02d_%02d%02d", identifierPrefix,
               comps.year ?? 0, comps.month ?? 0, comps.day ?? 0, comps.hour ?? 0, comps.minute ?? 0)
    }

    // MARK: - Private

    /// Removes every pending quote request and returns how many *other* requests stay pending.
    @discardableResult
    private func removePendingQuoteRequests() async -> Int {
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let quoteIDs = pending.filter(Self.isQuoteRequest(identifier:))
        center.removePendingNotificationRequests(withIdentifiers: quoteIDs)
        return pending.count - quoteIDs.count
    }

    #if DEBUG
    /// What `getPendingNotificationRequests` holds after a reschedule, for checking the slots
    /// on a simulator: `log stream --predicate 'category == "QuoteNotifications"'`.
    private func logPendingQuoteRequests() async {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE yyyy-MM-dd HH:mm"
        let dates = await center.pendingNotificationRequests()
            .filter { Self.isQuoteRequest(identifier: $0.identifier) }
            .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
            .sorted()
        for (index, date) in dates.enumerated() {
            Self.logger.debug("pending quote \(index + 1)/\(dates.count): \(formatter.string(from: date), privacy: .public)")
        }
    }
    #endif
}
