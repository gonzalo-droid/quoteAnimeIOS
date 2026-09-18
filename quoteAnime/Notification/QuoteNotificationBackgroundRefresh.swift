import Foundation
import BackgroundTasks
import os

/// What the refresh needs from `BGTaskScheduler`. A protocol so the tests can check what gets
/// submitted and cancelled without the system scheduler, which does nothing in a test host.
protocol AppRefreshScheduling {
    func submit(identifier: String, earliestBeginDate: Date) throws
    func cancel(identifier: String)
}

/// `BGTaskScheduler.shared` behind `AppRefreshScheduling`. Submitting again with the same
/// identifier replaces the pending request, so calling it on every trip to the background is safe.
struct SystemAppRefreshScheduler: AppRefreshScheduling {
    func submit(identifier: String, earliestBeginDate: Date) throws {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = earliestBeginDate
        try BGTaskScheduler.shared.submit(request)
    }

    func cancel(identifier: String) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
    }
}

/// Refills the quote notifications while the app stays closed.
///
/// Android chains its next quote from the worker that just fired, so it never runs dry. iOS runs
/// no code when a notification fires and books up to 64 in advance (`NotificationScheduler`),
/// which used to be refilled only when Home appeared: without opening the app they ran out
/// (~6 days at 10 a day, ~64 days at 1 a day). This asks iOS for a `BGAppRefreshTask` about once
/// a day and runs the same `RescheduleQuoteNotificationsUseCase` Home runs — which only touches
/// the `quote_*` requests, never a habit reminder.
///
/// iOS decides whether and when the task runs (it favours apps the user opens), so it can't be
/// relied on alone: the last booked slot of every batch is a "open the app" notice instead of a
/// quote (`NotificationScheduler.isRefillNotice`). Each refill books a new batch past it, so the
/// notice only fires if nothing refilled the batch in time.
///
/// The task is registered by `.backgroundTask(.appRefresh(...))` on the app's scene; its
/// identifier must stay listed in `BGTaskSchedulerPermittedIdentifiers` in `Info.plist`.
struct QuoteNotificationBackgroundRefresh {
    static let taskIdentifier = "com.gonzadev.quoteAnime.quoteNotificationsRefresh"

    /// Earliest a refresh may run after the previous request. A batch lasts at least ~6 days,
    /// so a daily refill keeps it full with a wide margin and costs one short fetch a day.
    static let interval: TimeInterval = 24 * 60 * 60

    private let getPreferences: GetUserPreferencesUseCase
    private let reschedule: RescheduleQuoteNotificationsUseCase
    private let scheduler: AppRefreshScheduling
    private let now: () -> Date

    private static let logger = Logger(subsystem: "com.gonzadev.quoteAnime", category: "QuoteNotifications")

    init(
        getPreferences: GetUserPreferencesUseCase,
        reschedule: RescheduleQuoteNotificationsUseCase,
        scheduler: AppRefreshScheduling = SystemAppRefreshScheduler(),
        now: @escaping () -> Date = Date.init
    ) {
        self.getPreferences = getPreferences
        self.reschedule = reschedule
        self.scheduler = scheduler
        self.now = now
    }

    /// Asks for the next refresh while quote notifications are on, and withdraws the request
    /// when they are off — there is nothing to refill then. Called when the app goes to the
    /// background and at the start of every refresh.
    func scheduleNext() {
        guard getPreferences.execute().notificationsEnabled else {
            scheduler.cancel(identifier: Self.taskIdentifier)
            return
        }
        do {
            try scheduler.submit(
                identifier: Self.taskIdentifier,
                earliestBeginDate: now().addingTimeInterval(Self.interval)
            )
        } catch {
            // `BGTaskScheduler` refuses in the simulator's older runtimes and when Background App
            // Refresh is off for the app; the notice slot covers that case.
            Self.logger.error("background refresh not submitted: \(String(describing: error), privacy: .public)")
        }
    }

    /// The task's body. Books the next request first, so a run that iOS cuts short still leaves
    /// one queued, then refills the quotes with the preferences as they are now.
    func run() async {
        scheduleNext()
        let preferences = getPreferences.execute()
        guard preferences.notificationsEnabled else { return }
        await reschedule.execute(preferences: preferences)
        Self.logger.info("background refresh refilled the quote notifications")
    }
}
