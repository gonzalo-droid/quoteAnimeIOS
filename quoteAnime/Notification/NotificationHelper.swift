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
    ///
    /// Its texts are resolved when it is delivered, not when it is booked: a batch is booked days
    /// ahead, and the app's language may change meanwhile (Ajustes › QuoteAnime › Idioma).
    /// Same pattern as the habit reminders' body; the keys are carried by hand in the catalog.
    static let refillNoticeTitleKey = "No te quedes sin frases"
    static let refillNoticeBodyKey = "Abre la app para seguir recibiendo frases de anime."

    static func makeRefillNoticeContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: refillNoticeTitleKey, arguments: nil)
        content.body  = NSString.localizedUserNotificationString(forKey: refillNoticeBodyKey, arguments: nil)
        content.sound = .default
        return content
    }
}
