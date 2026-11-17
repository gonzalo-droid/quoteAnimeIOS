import Foundation
import WidgetKit

// Shared keys between the main app and the widget extension.
enum WidgetSharedKeys {
    static let suiteName              = "group.com.gonzadev.quoteAnime"
    /// The Spanish text (`Quote.quote`).
    static let quoteText              = "widget_quote_text"
    /// The English text (`Quote.quoteEn`), removed when the quote has none. Both texts travel so
    /// the widget picks by *its* language when it renders, not the app's at write time.
    static let quoteTextEn            = "widget_quote_text_en"
    static let quoteAuthor            = "widget_quote_author"
    static let quoteAnime             = "widget_quote_anime"
    static let quoteId                = "widget_quote_id"
    static let imageUrl               = "widget_image_url"
    static let widgetUpdateTimesPerDay = "widget_update_times_per_day"
    /// Deliberately the *same* key name `UserPreferencesStore` uses in `UserDefaults.standard`:
    /// the anime selection is mirrored into the App Group so the widget extension can filter its
    /// own Firebase fetch with it. `UserPreferencesStore` owns writing it (and the one-time copy
    /// for users who chose their animes before the widget honoured them).
    static let selectedCategoryIds = "pref_selected_category_ids"
}

/// Writes the currently displayed quote to the App Group UserDefaults
/// so the WidgetKit extension can read it. Call this whenever the home quote changes.
enum WidgetDataWriter {
    static func write(_ quote: Quote) {
        guard let defaults = UserDefaults(suiteName: WidgetSharedKeys.suiteName) else { return }
        defaults.set(quote.quote,    forKey: WidgetSharedKeys.quoteText)
        defaults.set(quote.quoteEn,  forKey: WidgetSharedKeys.quoteTextEn)
        defaults.set(quote.author,   forKey: WidgetSharedKeys.quoteAuthor)
        defaults.set(quote.anime,    forKey: WidgetSharedKeys.quoteAnime)
        defaults.set(quote.id,       forKey: WidgetSharedKeys.quoteId)
        defaults.set(quote.imageUrl, forKey: WidgetSharedKeys.imageUrl)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
