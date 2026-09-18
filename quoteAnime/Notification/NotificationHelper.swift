import Foundation
import UserNotifications

enum NotificationHelper {
    static func makeContent(for quote: Quote) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title    = quote.anime
        // content.subtitle = "— \(quote.author)"
        content.body     = quote.quote
        content.sound    = .default
        return content
    }

    /// The last booked slot of a batch (`NotificationScheduler.isRefillNotice`). Only fires when
    /// nothing refilled the batch in time; tapping it opens the app, and Home books a new batch.
    static func makeRefillNoticeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "No te quedes sin frases")
        content.body  = String(localized: "Abre la app para seguir recibiendo frases de anime.")
        content.sound = .default
        return content
    }
}
