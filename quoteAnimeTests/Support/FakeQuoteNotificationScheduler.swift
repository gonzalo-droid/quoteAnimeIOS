import Foundation
import UserNotifications
@testable import quoteAnime

/// Records what the app asked the notification system to do. The real
/// `NotificationScheduler` talks to `UNUserNotificationCenter`, which a unit-test target
/// can't drive, so everything above it is tested through `QuoteNotificationScheduling`.
final class FakeQuoteNotificationScheduler: QuoteNotificationScheduling, @unchecked Sendable {

    /// One entry per `reschedule` call, in order.
    private(set) var scheduledBatches: [[Quote]] = []
    private(set) var cancelAllCount = 0
    private(set) var requestPermissionCount = 0

    var permissionGranted = true
    var status: UNAuthorizationStatus = .authorized

    /// The quote pool handed over by the most recent `reschedule`.
    var lastScheduledQuotes: [Quote]? { scheduledBatches.last }

    /// The animes present in the most recent batch, deduplicated.
    var lastScheduledAnimes: Set<String> { Set(lastScheduledQuotes?.map { $0.anime } ?? []) }

    func requestPermission() async -> Bool {
        requestPermissionCount += 1
        return permissionGranted
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func reschedule(preferences: UserPreferences, quotes: [Quote]) async {
        scheduledBatches.append(quotes)
    }

    func cancelAll() async {
        cancelAllCount += 1
    }
}
