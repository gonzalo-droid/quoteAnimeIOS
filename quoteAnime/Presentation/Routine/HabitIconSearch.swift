import Foundation

/// The icon picker's search (Android `1d9e231`, `HabitIconPicker.kt`), kept pure so the rule can be
/// tested without a view.
///
/// Same semantics as Android: the query is matched against each icon's **name in the user's
/// language** (`HabitIcons.label(for:)` — "Beber agua", "Drink water"), never against the stable key
/// or the category title; a substring anywhere in the name counts; categories keep their header and
/// only lose the icons that don't match, and a category left with none disappears; a blank query
/// shows everything.
///
/// Two deliberate differences, both so a phone keyboard finds what the user means:
/// - **Accents and case are ignored** ("musica" finds "Tocar música"). Android only ignores case,
///   so there "musica" finds nothing — reported as Android debt in `PARITY.md`.
/// - **Surrounding whitespace is trimmed**, so the space iOS autocorrect leaves after a word doesn't
///   empty the results.
enum HabitIconSearch {

    /// The categories to draw for `query`. `label` resolves an icon key to its visible name; it is
    /// injected so tests can pin a language instead of depending on the simulator's.
    static func filter(
        _ categories: [HabitIconCategory],
        query: String,
        locale: Locale = .current,
        label: (String) -> String
    ) -> [HabitIconCategory] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return categories }

        return categories.compactMap { category in
            let keys = category.keys.filter { matches(label($0), query: needle, locale: locale) }
            guard !keys.isEmpty else { return nil }
            return HabitIconCategory(id: category.id, title: category.title, keys: keys)
        }
    }

    /// Case- and diacritic-insensitive substring match.
    static func matches(_ name: String, query: String, locale: Locale = .current) -> Bool {
        name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], locale: locale) != nil
    }
}

extension HabitIcons {
    /// The icon's name resolved in `locale` — what the picker's search compares against. Only
    /// differs from `String(localized: label(for:))` when a test pins the language.
    static func localizedLabel(for key: String, locale: Locale = .current) -> String {
        var resource = label(for: key)
        resource.locale = locale
        return String(localized: resource)
    }
}
