import Foundation

/// Refills the pending-notification budget with quotes that match the user's anime selection.
///
/// Mirrors Android's `QuoteNotificationWorker`, which picks its quote with
/// `getRandomQuote(preferences.selectedCategoryIds)`: the anime selection decides which
/// quotes may be notified. Android re-picks on every fire; iOS has to pre-schedule the whole
/// batch (max 64 pending), so the filter is applied once, here, when the batch is built.
///
/// Single entry point on purpose — Home (app launch), Settings (any preference change) and
/// the anime selection screen all reschedule through this, so none of them can forget the filter.
struct RescheduleQuoteNotificationsUseCase {
    private let getAllQuotes: GetAllQuotesUseCase
    private let scheduler: QuoteNotificationScheduling

    init(getAllQuotes: GetAllQuotesUseCase, scheduler: QuoteNotificationScheduling) {
        self.getAllQuotes = getAllQuotes
        self.scheduler = scheduler
    }

    /// Hands the scheduler the quotes allowed by `preferences.selectedCategoryIds`.
    ///
    /// Pass `pool` when the caller already has the quotes in hand (Home just loaded the feed) to
    /// avoid a second fetch; the pool is filtered here regardless, so a caller can't leak an
    /// unfiltered list into the schedule. Does nothing when notifications are off, or when there
    /// is nothing to schedule — the pending notifications are then left alone rather than wiped.
    func execute(preferences: UserPreferences, pool: [Quote]? = nil) async {
        guard preferences.notificationsEnabled else { return }
        let quotes: [Quote]
        if let pool {
            quotes = GetAllQuotesUseCase.filtered(pool, by: preferences.selectedCategoryIds)
        } else {
            guard let fetched = try? await getAllQuotes.execute(filteredBy: preferences.selectedCategoryIds)
            else { return }
            quotes = fetched
        }
        guard !quotes.isEmpty else { return }
        await scheduler.reschedule(preferences: preferences, quotes: quotes)
    }
}
