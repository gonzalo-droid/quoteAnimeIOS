import Foundation

/// Cover art and flavour text of the themed suggestions — Android's `HabitThemeImages.kt`
/// (`923e552`, `3153211`) and `THEME_DESCRIPTION_RES_BY_KEY` in its `HabitIcons.kt`.
///
/// Keyed by `HabitTemplate.themeKey`, which a habit created from a suggestion persists as
/// `Habit.coverAnimeSlug`. **Those keys are stored**, so never rename one: a habit saved with it
/// would silently lose its cover. The asset names are free to change.
///
/// The images are Android's `res/drawable/*.png` (1080×1350, no density variants), re-encoded as
/// JPEG at 80 %: 4.2 MB → 0.8 MB for the five, with no visible difference at the sizes they are
/// drawn (a 108 pt preview and a card background under an 82 % scrim).
enum HabitThemeImages {
    private static let assetByThemeKey: [String: String] = [
        "ninja": "habit_cover_naruto",
        "one_piece": "habit_cover_onepiece",
        "saiyan": "habit_cover_dragonball",
        "pokemon": "habit_cover_pokemon",
        "black_clover": "habit_cover_blackclover",
    ]

    private static let descriptionByThemeKey: [String: LocalizedStringResource] = [
        "ninja": "Como todo ninja, la disciplina diaria es tu mayor entrenamiento.",
        "one_piece": "Cada hábito cumplido es un paso más cerca de tu propio tesoro.",
        "saiyan": "Entrena cada día hasta superar tus límites, como un guerrero saiyan.",
        "pokemon": "Entrena cada día para hacerte más fuerte, como un verdadero maestro Pokémon.",
        "black_clover": "Sin magia, con pura garra: cada hábito te acerca a ser el Rey Mago.",
    ]

    /// Name of the cover in `Assets.xcassets`, or nil for a habit without a theme (or with a key
    /// this build doesn't know) — callers then draw the flat accent fallback, as Android does.
    static func assetName(for themeKey: String?) -> String? {
        themeKey.flatMap { assetByThemeKey[$0] }
    }

    /// The suggestion's flavour text in the user's language — prefilled as the habit's description
    /// when the suggestion is picked, like Android's `resolveThemeDescription`.
    static func description(for themeKey: String?) -> String? {
        themeKey.flatMap { descriptionByThemeKey[$0] }.map { String(localized: $0) }
    }

    /// Every theme key with a cover — for the test that walks the asset catalog.
    static var themeKeys: [String] { Array(assetByThemeKey.keys) }
}
