import Foundation

struct Quote: Identifiable, Codable {
    let id: String
    /// The quote in Spanish — every quote has it.
    let quote: String
    /// The English translation (`quoteEn` in `/quotes`); nil until the quote is translated.
    /// Never read it directly to show a quote: `text(forLanguageCode:)` / `localizedText`.
    let quoteEn: String?
    let author: String
    let anime: String
    let categories: [String]
    let animeSlug: String?
    /// Length bucket from the database (`"xs"`…). Decoded and carried, not used yet.
    let size: String?
    var imageUrl: String?
    var isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case id, quote, quoteEn, author, anime, categories, animeSlug, size, isFavorite
        // imageUrl is intentionally excluded — resolved at runtime, never persisted
    }

    init(
        id: String,
        quote: String,
        quoteEn: String? = nil,
        author: String,
        anime: String,
        categories: [String] = [],
        animeSlug: String? = nil,
        size: String? = nil,
        imageUrl: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.quote = quote
        self.quoteEn = quoteEn
        self.author = author
        self.anime = anime
        self.categories = categories
        self.animeSlug = animeSlug
        self.size = size
        self.imageUrl = imageUrl
        self.isFavorite = isFavorite
    }

    /// The same quote with the English text filled in, when this copy has none — a favorite
    /// saved before `quoteEn` existed, enriched from the feed.
    func withTranslation(from other: Quote) -> Quote {
        guard QuoteText.nonBlank(quoteEn) == nil, QuoteText.nonBlank(other.quoteEn) != nil else { return self }
        return Quote(
            id: id, quote: quote, quoteEn: other.quoteEn, author: author, anime: anime,
            categories: categories, animeSlug: animeSlug, size: size ?? other.size,
            imageUrl: imageUrl, isFavorite: isFavorite
        )
    }
}

extension Quote: Hashable {
    static func == (lhs: Quote, rhs: Quote) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Quote {
    /// The text to show in the app language `code`: `quote` in Spanish, `quoteEn` in any other
    /// language (the UI falls back to English too). See `QuoteText.select`.
    func text(forLanguageCode code: String) -> String {
        QuoteText.select(spanish: quote, english: quoteEn, languageCode: code)
    }
}

/// Which of a quote's two texts to show — Android's `Quote.textFor(locale)`.
///
/// Pure, so the widget extension can keep an identical copy (`WidgetQuoteText` in
/// `QuoteAnimeWidget/WidgetSharedModel.swift`) — change both together.
enum QuoteText {
    /// Spanish (`es`, `es-PE`, `es_419`…) shows `spanish`; every other language shows `english`.
    /// A missing or blank text falls back to the other one, so a quote is never empty just
    /// because it isn't translated yet.
    static func select(spanish: String, english: String?, languageCode: String) -> String {
        let es = nonBlank(spanish)
        let en = nonBlank(english)
        let text = isSpanish(languageCode) ? (es ?? en) : (en ?? es)
        return text ?? ""
    }

    static func isSpanish(_ languageCode: String) -> Bool {
        languageCode.prefix { $0 != "-" && $0 != "_" }.lowercased() == "es"
    }

    static func nonBlank(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}
