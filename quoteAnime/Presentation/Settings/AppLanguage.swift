import Foundation

/// The language the app is showing, for the Settings "Idioma" row.
///
/// iOS has no API for an app to switch its own language: the per-app choice lives in the
/// system Settings (Ajustes › QuoteAnime › Idioma), which iOS shows on its own because the app
/// ships more than one localization. Changing it there relaunches the app, the widget extension
/// included. So the row only reports the current language and opens that page — the same choice
/// Android's Settings picker writes through `LocaleManager`.
enum AppLanguage {
    /// The localization the bundle actually resolved to (`en` or `es`), not the phone's.
    static func currentCode(bundle: Bundle = .main) -> String {
        bundle.preferredLocalizations.first ?? "en"
    }

    /// The language's own name ("English", "Español"), so it reads the same whatever the app's
    /// language is — like the system's picker.
    static func displayName(forCode code: String) -> String {
        let language = String(code.prefix { $0 != "-" && $0 != "_" })
        let locale = Locale(identifier: language)
        guard let name = locale.localizedString(forLanguageCode: language) else { return code }
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }
}
