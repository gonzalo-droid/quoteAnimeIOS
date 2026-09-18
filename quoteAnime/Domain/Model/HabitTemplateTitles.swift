import Foundation

/// What a remote template's `title` becomes on screen.
///
/// `/habitTemplates` carries Android's **string-resource key** (`template_theme_ninja`), which
/// Android resolves with `TEMPLATE_TITLE_RES_BY_KEY` in its `HabitIcons.kt`. iOS catalogs are
/// keyed by the Spanish text instead, so this table maps each Android key to the iOS string —
/// same wording as `values{,-es}/strings.xml`, in the user's language.
///
/// Android's resolver falls back to showing the title as-is, which is right for a literal text
/// ("Leer 20 minutos") and wrong for a key published remotely before an app release knows it: the
/// user would see `template_theme_bleach` on a chip. iOS tells the two apart by shape — a
/// snake_case identifier is a key — and **drops a template whose key it doesn't know** instead
/// of showing an id. A suggestion needs a name to be worth offering; the next release that adds
/// the key brings it back. See `PARITY.md`.
enum HabitTemplateTitles {
    /// The localized title, a literal title unchanged, or nil for a key this build doesn't know.
    static func displayTitle(for raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let known = localized(forKey: trimmed) { return known }
        return looksLikeKey(trimmed) ? nil : trimmed
    }

    /// Every Android key this build knows — for the tests.
    static let knownKeys: [String] = [
        "template_train", "template_read", "template_meditate", "template_water",
        "template_sleep_early", "template_study", "template_write", "template_walk",
        "template_theme_ninja", "template_theme_one_piece", "template_theme_saiyan",
        "template_theme_pokemon", "template_theme_black_clover",
    ]

    static func localized(forKey key: String) -> String? {
        switch key {
        case "template_train": return String(localized: "Entrenar")
        case "template_read": return String(localized: "Leer")
        case "template_meditate": return String(localized: "Meditar")
        case "template_water": return String(localized: "Beber agua")
        case "template_sleep_early": return String(localized: "Dormir temprano")
        case "template_study": return String(localized: "Estudiar")
        case "template_write": return String(localized: "Escribir")
        case "template_walk": return String(localized: "Caminar")
        case "template_theme_ninja": return String(localized: "Camino ninja")
        case "template_theme_one_piece": return String(localized: "Buscar el One Piece")
        case "template_theme_saiyan": return String(localized: "Sé un saiyan")
        case "template_theme_pokemon": return String(localized: "Sé un maestro Pokémon")
        case "template_theme_black_clover": return String(localized: "Sé el Rey Mago")
        default: return nil
        }
    }

    /// `template_theme_bleach`, `habit_x`: lowercase words joined by underscores. Real titles have
    /// spaces, capitals or accents; a one-word lowercase title ("leer") is shown as it is.
    static func looksLikeKey(_ text: String) -> Bool {
        text.wholeMatch(of: #/[a-z0-9]+(_[a-z0-9]+)+/#) != nil
    }
}
