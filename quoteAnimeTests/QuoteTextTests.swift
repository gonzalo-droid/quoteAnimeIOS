import Foundation
import Testing
@testable import quoteAnime

/// `/quotes` now carries `quoteEn` next to the Spanish `quote`. The app shows the Spanish text in
/// Spanish and the English one in every other language (the UI falls back to English too), and a
/// quote that isn't translated yet shows its Spanish text rather than nothing — Android's
/// `Quote.textFor(locale)`.
@Suite("Texto de la frase según el idioma")
struct QuoteTextSelectionTests {

    private static let spanish = "Nunca retrocedo a mi palabra, ese es mi camino ninja."
    private static let english = "I never go back on my word. That's my ninja way."

    @Test("español muestra quote; cualquier otro idioma, quoteEn", arguments: [
        ("es", spanish), ("es-PE", spanish), ("es_419", spanish), ("ES", spanish),
        ("en", english), ("en-US", english), ("pt-BR", english), ("fr", english), ("", english),
    ])
    func picksByLanguage(code: String, expected: String) {
        let quote = Quote(id: "1", quote: Self.spanish, quoteEn: Self.english, author: "Naruto Uzumaki", anime: "Naruto")
        #expect(quote.text(forLanguageCode: code) == expected)
    }

    @Test("sin traducción (nil, vacía o en blanco) se muestra el español", arguments: [
        nil, "", "   ", "\n",
    ] as [String?])
    func missingTranslationFallsBackToSpanish(english: String?) {
        let quote = Quote(id: "1", quote: Self.spanish, quoteEn: english, author: "a", anime: "b")
        #expect(quote.text(forLanguageCode: "en") == Self.spanish)
        #expect(quote.text(forLanguageCode: "es") == Self.spanish)
    }

    @Test("un español en blanco cae a la traducción en vez de quedar vacío")
    func blankSpanishFallsBackToEnglish() {
        let quote = Quote(id: "1", quote: " ", quoteEn: Self.english, author: "a", anime: "b")
        #expect(quote.text(forLanguageCode: "es") == Self.english)
    }

    @Test("el idioma de la app decide: localizedText sigue a AppLanguage")
    func localizedTextFollowsAppLanguage() {
        let quote = Quote(id: "1", quote: Self.spanish, quoteEn: Self.english, author: "a", anime: "b")
        let expected = QuoteText.isSpanish(AppLanguage.currentCode()) ? Self.spanish : Self.english
        #expect(quote.localizedText == expected)
    }

    @Test("la notificación usa el texto del idioma de la app")
    func notificationBodyIsLocalized() {
        let quote = Quote(id: "1", quote: Self.spanish, quoteEn: Self.english, author: "a", anime: "Naruto")
        #expect(NotificationHelper.makeContent(for: quote).body == quote.localizedText)
    }
}

@Suite("Decodificación de /quotes con y sin quoteEn")
struct QuoteDTODecodingTests {

    @Test("una frase nueva trae quoteEn, categories, animeSlug y size")
    func decodesNewShape() throws {
        let dict: [String: Any] = [
            "anime": "Naruto",
            "author": "Naruto Uzumaki",
            "quote": "Nunca retrocedo a mi palabra, ese es mi camino ninja.",
            "quoteEn": "I never go back on my word. That's my ninja way.",
            "categories": ["motivación", "orgullo"],
            "animeSlug": "naruto",
            "size": "xs",
        ]
        let dto = try #require(QuoteDTO(dict: dict, key: "45"))
        let quote = dto.toDomain()
        #expect(quote.id == "45")
        #expect(quote.quoteEn == "I never go back on my word. That's my ninja way.")
        #expect(quote.categories == ["motivación", "orgullo"])
        #expect(quote.animeSlug == "naruto")
        #expect(quote.size == "xs")
    }

    @Test("una frase vieja, sin los campos nuevos, se sigue leyendo")
    func decodesOldShape() throws {
        let dict: [String: Any] = ["anime": "Naruto", "author": "Rock Lee", "quote": "El esfuerzo supera al talento."]
        let quote = try #require(QuoteDTO(dict: dict, key: "7")).toDomain()
        #expect(quote.quoteEn == nil)
        #expect(quote.size == nil)
        #expect(quote.animeSlug == nil)
        #expect(quote.categories.isEmpty)
        #expect(quote.text(forLanguageCode: "en") == "El esfuerzo supera al talento.")
    }

    @Test("quoteEn null o que no es texto cuenta como sin traducción")
    func nullOrWrongTypeTranslation() throws {
        for value in [NSNull(), 42 as Any] {
            let dict: [String: Any] = ["anime": "a", "author": "b", "quote": "Hola", "quoteEn": value]
            let quote = try #require(QuoteDTO(dict: dict, key: "1")).toDomain()
            #expect(quote.quoteEn == nil)
            #expect(quote.text(forLanguageCode: "en") == "Hola")
        }
    }
}

@Suite("Favoritos guardan la traducción")
struct FavoriteQuoteTranslationTests {

    @Test("favoritos de iOS 16 guardados antes de quoteEn se siguen leyendo")
    func legacyUserDefaultsJSONDecodes() throws {
        // The exact shape `UserDefaultsFavoriteStorage` wrote before `quoteEn` and `size`.
        let json = #"[{"id":"7","quote":"Hola","author":"a","anime":"b","categories":[],"isFavorite":true}]"#
        let quotes = try JSONDecoder().decode([Quote].self, from: Data(json.utf8))
        #expect(quotes.first?.quoteEn == nil)
        #expect(quotes.first?.quote == "Hola")
    }

    @Test("favoritos de iOS 16 guardan y releen quoteEn")
    func userDefaultsRoundTrip() throws {
        let quote = Quote(id: "1", quote: "Hola", quoteEn: "Hello", author: "a", anime: "b", isFavorite: true)
        let decoded = try JSONDecoder().decode([Quote].self, from: JSONEncoder().encode([quote]))
        #expect(decoded.first?.quoteEn == "Hello")
    }

    @available(iOS 17, *)
    @Test("el modelo SwiftData conserva quoteEn")
    func swiftDataModelKeepsTranslation() {
        let quote = Quote(id: "1", quote: "Hola", quoteEn: "Hello", author: "a", anime: "b")
        #expect(FavoriteQuoteModel(from: quote).toDomain().quoteEn == "Hello")
    }

    @Test("un favorito sin traducción la toma del feed; uno traducido no se toca")
    func enrichmentFromFeed() {
        let feed = Quote(id: "1", quote: "Hola", quoteEn: "Hello", author: "a", anime: "b", size: "xs")
        let old = Quote(id: "1", quote: "Hola", author: "a", anime: "b", isFavorite: true)
        let enriched = old.withTranslation(from: feed)
        #expect(enriched.quoteEn == "Hello")
        #expect(enriched.isFavorite)

        let translated = Quote(id: "1", quote: "Hola", quoteEn: "Hi", author: "a", anime: "b")
        #expect(translated.withTranslation(from: feed).quoteEn == "Hi")
    }
}

/// The widget extension can't import `QuoteText`, so it keeps a copy (`WidgetQuoteText`). This
/// fails if the two bodies stop being identical.
@Suite("Copia del widget de QuoteText")
struct WidgetQuoteTextCopyTests {

    @Test("las tres funciones son iguales en la app y en el widget", arguments: ["select", "isSpanish", "nonBlank"])
    func widgetCopyMatches(function: String) throws {
        let app = try Self.source("quoteAnime/Domain/Model/Quote.swift")
        let widget = try Self.source("QuoteAnimeWidget/WidgetSharedModel.swift")
        let appBody = try #require(Self.body(of: function, in: app))
        let widgetBody = try #require(Self.body(of: function, in: widget))
        #expect(appBody == widgetBody)
    }

    @Test("el widget guarda las dos claves de texto que escribe la app")
    func sharedKeysMatch() throws {
        let widget = try Self.source("QuoteAnimeWidget/WidgetSharedModel.swift")
        #expect(widget.contains("\"\(WidgetSharedKeys.quoteText)\""))
        #expect(widget.contains("\"\(WidgetSharedKeys.quoteTextEn)\""))
    }

    private static func body(of function: String, in source: String) -> String? {
        guard let start = source.range(of: "static func \(function)(") else { return nil }
        guard let end = source.range(of: "\n    }\n", range: start.upperBound..<source.endIndex) else { return nil }
        return String(source[start.lowerBound..<end.upperBound])
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // quoteAnimeTests
        .deletingLastPathComponent()   // repo root
}
