import Foundation

/// Translates icon keys that were persisted by mistake into the stable keys of `HabitIcons`.
///
/// Until the fix, `DefaultHabitTemplates` stored raw SF Symbol names as `iconKey`, so every habit
/// created from a template was saved with a value `HabitIcons` doesn't know — and rendered the
/// generic check forever. Those rows stay as they are on disk; instead, every read goes through
/// `canonical(_:)` (`HabitModel.toDomain()`), so the rest of the app only ever sees stable keys and
/// the next save of that habit writes the correct key back. No store migration is needed, and the
/// alias table can never be wrong for a habit that was saved correctly, because none of these
/// symbol names is a stable key.
///
/// The targets are the keys Android uses for the same templates (`DefaultHabitTemplates.kt`).
/// **Never remove an entry**: a habit untouched since then still carries the old value.
enum HabitIconAliases {
    static let legacyToStable: [String: String] = [
        "figure.strengthtraining.traditional": "dumbbell",   // theme_ninja
        "figure.walk": "directions_walk",                    // theme_one_piece
        "figure.mind.and.body": "self_improvement",          // theme_saiyan
        "sportscourt": "emoji_events",                       // theme_pokemon
        "sparkles": "local_fire_department"                  // theme_black_clover
    ]

    /// The stable key for `key`; keys that aren't legacy aliases pass through untouched.
    static func canonical(_ key: String) -> String {
        legacyToStable[key] ?? key
    }
}
