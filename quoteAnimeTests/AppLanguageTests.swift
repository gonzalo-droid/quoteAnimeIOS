import Foundation
import Testing
@testable import quoteAnime

@Suite("AppLanguage")
struct AppLanguageTests {

    @Test("cada idioma se nombra en su propio idioma", arguments: [
        ("en", "English"), ("es", "Español"), ("es-PE", "Español"), ("en_US", "English"),
    ])
    func endonym(code: String, expected: String) {
        #expect(AppLanguage.displayName(forCode: code) == expected)
    }

    @Test("la app trae exactamente inglés y español")
    func shippedLocalizations() {
        let shipped = Set(Bundle(for: PremiumGate.self).localizations.filter { $0 != "Base" })
        #expect(shipped == ["en", "es"])
    }
}

@Suite("Textos resueltos al entregar la notificación")
struct DeliveryTimeLocalizationTests {

    /// Estas claves no las extrae el compilador (se leen al entregar la notificación), así que
    /// una traducción que falte sólo se notaría en un iPhone en inglés.
    @Test("las claves a mano tienen traducción al inglés", arguments: [
        NotificationHelper.refillNoticeTitleKey,
        NotificationHelper.refillNoticeBodyKey,
        HabitReminderScheduler.reminderBodyKey,
    ])
    func manualKeysAreTranslated(key: String) throws {
        let appBundle = Bundle(for: PremiumGate.self)
        let path = try #require(appBundle.path(forResource: "en", ofType: "lproj"))
        let english = try #require(Bundle(path: path))
        let value = english.localizedString(forKey: key, value: "<missing>", table: nil)
        #expect(value != "<missing>")
        #expect(value != key)
    }
}
