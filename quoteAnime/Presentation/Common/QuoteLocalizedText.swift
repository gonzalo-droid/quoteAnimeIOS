import Foundation

extension Quote {
    /// The quote's text in the language the app is showing (`AppLanguage.currentCode()`, which
    /// follows the device language and iOS's per-app language). Changing the per-app language
    /// relaunches the app, so reading it on each render is enough — nothing needs to observe it.
    var localizedText: String { text(forLanguageCode: AppLanguage.currentCode()) }
}
