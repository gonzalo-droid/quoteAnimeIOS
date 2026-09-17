import Foundation
import Testing
@testable import quoteAnime

/// The app ships Spanish (source language) and English through String Catalogs.
///
/// Two kinds of check live here:
/// - **Resolution**: what the compiled catalog in the app bundle actually returns for a given
///   language, plural counts included. `LocalizedStringResource` carries its own `locale`, which
///   is what picks the `.lproj` — so the result doesn't depend on the simulator's language.
/// - **Completeness**: every key of every catalog (app and widget extension) has a finished
///   Spanish and English value. The widget's catalog is compiled into the extension, which a
///   unit test can't load, so the catalogs are read from the source tree instead.
@Suite("Localización")
struct LocalizationTests {

    private static let spanish = Locale(identifier: "es")
    private static let english = Locale(identifier: "en")

    private static func resolve(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    // MARK: - Plurals

    @Test(
        "la racha usa singular y plural en español",
        arguments: [
            (0, "0 días seguidos"),
            (1, "1 día seguido"),
            (2, "2 días seguidos"),
            (5, "5 días seguidos"),
        ]
    )
    func streakSpanish(count: Int, expected: String) {
        let text = Self.resolve(LocalizedStringResource("\(count) días seguidos", locale: Self.spanish))
        #expect(text == expected)
    }

    @Test(
        "la racha se traduce al inglés como en Android",
        arguments: [
            (0, "0 day streak"),
            (1, "1 day streak"),
            (2, "2 day streak"),
            (5, "5 day streak"),
        ]
    )
    func streakEnglish(count: Int, expected: String) {
        let text = Self.resolve(LocalizedStringResource("\(count) días seguidos", locale: Self.english))
        #expect(text == expected)
    }

    @Test(
        "el resumen de animes elegidos respeta el plural",
        arguments: [
            (1, "1 anime", "1 anime"),
            (2, "2 animes", "2 anime"),
            (5, "5 animes", "5 anime"),
        ]
    )
    func animeCount(count: Int, spanish: String, english: String) {
        #expect(Self.resolve(LocalizedStringResource("\(count) animes", locale: Self.spanish)) == spanish)
        #expect(Self.resolve(LocalizedStringResource("\(count) animes", locale: Self.english)) == english)
    }

    @Test(
        "la frecuencia de notificaciones dice vez/veces y time/times",
        arguments: [
            (1, "Frecuencia: 1 vez al día", "Frequency: 1 time a day"),
            (2, "Frecuencia: 2 veces al día", "Frequency: 2 times a day"),
            (10, "Frecuencia: 10 veces al día", "Frequency: 10 times a day"),
        ]
    )
    func notificationFrequency(count: Int, spanish: String, english: String) {
        #expect(Self.resolve(LocalizedStringResource("Frecuencia: \(count) veces al día", locale: Self.spanish)) == spanish)
        #expect(Self.resolve(LocalizedStringResource("Frecuencia: \(count) veces al día", locale: Self.english)) == english)
    }

    @Test(
        "la frecuencia del widget usa el mismo plural que Android",
        arguments: [
            (1, "Nueva frase 1 vez al día", "New quote 1 time a day"),
            (3, "Nueva frase 3 veces al día", "New quote 3 times a day"),
        ]
    )
    func widgetFrequency(count: Int, spanish: String, english: String) {
        #expect(Self.resolve(LocalizedStringResource("Nueva frase \(count) veces al día", locale: Self.spanish)) == spanish)
        #expect(Self.resolve(LocalizedStringResource("Nueva frase \(count) veces al día", locale: Self.english)) == english)
    }

    @Test(
        "el aviso de límite nombra el máximo con el número correcto",
        arguments: [
            (1, "Con el plan gratuito puedes tener 1 hábito activo a la vez. Archívalo o pásate a premium para agregar más.",
             "On the free plan you can have 1 active habit at a time. Archive it or go premium to add more."),
            (3, "Con el plan gratuito puedes tener 3 hábitos activos a la vez. Archiva uno o pásate a premium para agregar más.",
             "On the free plan you can have 3 active habits at a time. Archive one or go premium to add more."),
        ]
    )
    func habitLimit(max: Int, spanish: String, english: String) {
        let key: (Locale) -> LocalizedStringResource = {
            LocalizedStringResource(
                "Con el plan gratuito puedes tener \(max) hábitos activos a la vez. Archiva uno o pásate a premium para agregar más.",
                locale: $0
            )
        }
        #expect(Self.resolve(key(Self.spanish)) == spanish)
        #expect(Self.resolve(key(Self.english)) == english)
    }

    @Test(
        "el mapa de actividad nombra las semanas en singular y plural",
        arguments: [
            (1, "Mapa de actividad de la última semana", "Activity map for the last week"),
            (26, "Mapa de actividad de las últimas 26 semanas", "Activity map for the last 26 weeks"),
        ]
    )
    func heatmapWeeks(weeks: Int, spanish: String, english: String) {
        #expect(Self.resolve(LocalizedStringResource("Mapa de actividad de las últimas \(weeks) semanas", locale: Self.spanish)) == spanish)
        #expect(Self.resolve(LocalizedStringResource("Mapa de actividad de las últimas \(weeks) semanas", locale: Self.english)) == english)
    }

    // MARK: - Strings that aren't plurals but are easy to break

    @Test("dos argumentos conservan su orden en ambos idiomas")
    func positionalArguments() {
        #expect(Self.resolve(LocalizedStringResource("Paso \(2) de \(4)", locale: Self.english)) == "Step 2 of 4")
        #expect(Self.resolve(LocalizedStringResource("Paso \(2) de \(4)", locale: Self.spanish)) == "Paso 2 de 4")
        let start = "1 mar 2026", end = "5 abr 2026"
        #expect(Self.resolve(LocalizedStringResource("Del \(start) al \(end)", locale: Self.english)) == "From 1 mar 2026 to 5 abr 2026")
    }

    @Test("el tuteo reemplazó al voseo")
    func spanishUsesTu() {
        #expect(Self.resolve(LocalizedStringResource("Ya eres premium ✨", locale: Self.spanish)) == "Ya eres premium ✨")
        #expect(Self.resolve(LocalizedStringResource("Ya eres premium ✨", locale: Self.english)) == "You're premium ✨")
    }

    /// The reminder body is looked up with `localizedUserNotificationString(forKey:)` at delivery
    /// time, so nothing extracts it from code. This pins that the hand-added key is in both
    /// compiled tables.
    @Test("el cuerpo del recordatorio existe en las dos tablas compiladas", arguments: [
        ("es", "¿Ya completaste tu hábito de hoy?"),
        ("en", "Have you completed your habit today?"),
    ])
    func reminderBodyIsCompiled(language: String, expected: String) throws {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        let value = bundle.localizedString(forKey: HabitReminderScheduler.reminderBodyKey, value: "∅", table: nil)
        #expect(value == expected)
    }

    @Test("la app declara español como idioma de desarrollo y trae inglés")
    func bundleLocalizations() {
        #expect(Bundle.main.developmentLocalization == "es")
        #expect(Set(Bundle.main.localizations).isSuperset(of: ["es", "en"]))
    }

    // MARK: - Catalog completeness

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // quoteAnimeTests
        .deletingLastPathComponent()   // repo root

    nonisolated static let catalogs = [
        "quoteAnime/Localizable.xcstrings",
        "quoteAnime/InfoPlist.xcstrings",
        "QuoteAnimeWidget/Localizable.xcstrings",
    ]

    @Test("todas las claves tienen español e inglés terminados", arguments: catalogs)
    func catalogIsComplete(path: String) throws {
        let catalog = try StringCatalog.load(Self.repoRoot.appendingPathComponent(path))

        #expect(catalog.sourceLanguage == "es")
        #expect(!catalog.strings.isEmpty)

        var problems: [String] = []
        for (key, entry) in catalog.strings {
            for language in ["es", "en"] {
                guard let localization = entry.localizations?[language] else {
                    problems.append("\(key) — falta \(language)")
                    continue
                }
                problems += localization.problems(key: key, language: language)
            }
        }
        #expect(problems.isEmpty, "\(path):\n\(problems.sorted().joined(separator: "\n"))")
    }

    /// A translation that drops or adds a `%@`/`%lld` crashes or prints garbage at runtime.
    /// Plural `one` variants may drop the number ("la última semana"), so only `other` is checked.
    @Test("las traducciones conservan los mismos especificadores de formato", arguments: catalogs)
    func formatSpecifiersMatch(path: String) throws {
        let catalog = try StringCatalog.load(Self.repoRoot.appendingPathComponent(path))

        var problems: [String] = []
        for (key, entry) in catalog.strings {
            let expected = StringCatalog.specifiers(in: key)
            for (language, localization) in entry.localizations ?? [:] {
                guard let value = localization.stringUnit?.value
                        ?? localization.variations?.plural?["other"]?.stringUnit?.value else { continue }
                let found = StringCatalog.specifiers(in: value)
                if found != expected {
                    problems.append("\(key) [\(language)]: \(expected) ≠ \(found)")
                }
            }
        }
        #expect(problems.isEmpty, "\(path):\n\(problems.sorted().joined(separator: "\n"))")
    }
}

/// Just enough of the `.xcstrings` JSON schema to check it.
private struct StringCatalog: Decodable {
    struct StringUnit: Decodable {
        let state: String
        let value: String
    }

    struct Variations: Decodable {
        let plural: [String: Localization]?
    }

    struct Localization: Decodable {
        let stringUnit: StringUnit?
        let variations: Variations?

        func problems(key: String, language: String) -> [String] {
            if let unit = stringUnit {
                return Self.check(unit, label: "\(key) [\(language)]")
            }
            guard let plural = variations?.plural else {
                return ["\(key) [\(language)] — sin valor ni variaciones"]
            }
            var result: [String] = []
            for form in ["one", "other"] where plural[form] == nil {
                result.append("\(key) [\(language)] — falta la forma plural \(form)")
            }
            for (form, variant) in plural {
                guard let unit = variant.stringUnit else {
                    result.append("\(key) [\(language)/\(form)] — sin valor")
                    continue
                }
                result += Self.check(unit, label: "\(key) [\(language)/\(form)]")
            }
            return result
        }

        private static func check(_ unit: StringUnit, label: String) -> [String] {
            var result: [String] = []
            if unit.state != "translated" { result.append("\(label) — estado \(unit.state)") }
            if unit.value.trimmingCharacters(in: .whitespaces).isEmpty { result.append("\(label) — vacío") }
            return result
        }
    }

    struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    let sourceLanguage: String
    let strings: [String: Entry]

    static func load(_ url: URL) throws -> StringCatalog {
        try JSONDecoder().decode(StringCatalog.self, from: Data(contentsOf: url))
    }

    /// Format specifiers with positions stripped, sorted: `"Del %1$@ al %2$@"` → `["%@", "%@"]`.
    static func specifiers(in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(lld|ld|d|@)")
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range)
            .map { "%" + (text as NSString).substring(with: $0.range(at: 1)) }
            .sorted()
    }
}
