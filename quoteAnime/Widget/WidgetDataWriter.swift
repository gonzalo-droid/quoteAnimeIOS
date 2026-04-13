import Foundation
import WidgetKit

// Shared keys between the main app and the widget extension.
enum WidgetSharedKeys {
    static let suiteName              = "group.com.gonzadev.quoteAnime"
    static let quoteText              = "widget_quote_text"
    static let quoteAuthor            = "widget_quote_author"
    static let quoteAnime             = "widget_quote_anime"
    static let quoteId                = "widget_quote_id"
    static let imageUrl               = "widget_image_url"
    static let widgetUpdateTimesPerDay = "widget_update_times_per_day"
}

/// Writes the currently displayed quote to the App Group UserDefaults
/// so the WidgetKit extension can read it. Call this whenever the home quote changes.
enum WidgetDataWriter {
    static func write(_ quote: Quote) {
        guard let defaults = UserDefaults(suiteName: WidgetSharedKeys.suiteName) else { return }
        defaults.set(quote.quote,    forKey: WidgetSharedKeys.quoteText)
        defaults.set(quote.author,   forKey: WidgetSharedKeys.quoteAuthor)
        defaults.set(quote.anime,    forKey: WidgetSharedKeys.quoteAnime)
        defaults.set(quote.id,       forKey: WidgetSharedKeys.quoteId)
        defaults.set(quote.imageUrl, forKey: WidgetSharedKeys.imageUrl)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
