import Foundation
import UserNotifications

enum NotificationHelper {
    static func makeContent(for quote: Quote) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title    = quote.anime
        content.subtitle = "— \(quote.author)"
        content.body     = quote.quote
        content.sound    = .default
        return content
    }
}
