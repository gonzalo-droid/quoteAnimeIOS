import Foundation

struct HabitTemplate: Identifiable, Hashable {
    let id: String
    let title: String
    /// A stable `HabitIcons` key, never an SF Symbol name — same keys as Android's templates.
    let iconKey: String
    let order: Int
    /// Suggested HabitPalette index, for themed templates.
    let themeColorIndex: Int?
    /// Opaque key the presentation layer can resolve to a theme description. No bundled
    /// cover images exist yet on iOS (Android has naruto.png/onepiece.png/etc. — not
    /// ported here), so this is currently just a description hook.
    let themeKey: String?
    var isPremiumOnly: Bool = false
}

extension HabitTemplate {
    /// The padlock rule, in one place, so the editor's chips and anything else offering templates
    /// cannot drift apart. A locked chip stays tappable on purpose — it routes to the paywall
    /// instead of being greyed out, same as Android.
    func isLocked(isPremium: Bool) -> Bool {
        isPremiumOnly && !isPremium
    }
}

/// Bundled fallback — same 5 themes Android ships, same 2 locked behind Premium (Pokémon,
/// Black Clover). The original 3 stay free so no existing user loses anything.
///
/// Titles are resolved in the user's language once, when first read: choosing a template copies
/// its title into `Habit.title`, which is the user's own text from then on and never re-translated.
enum DefaultHabitTemplates {
    static let all: [HabitTemplate] = [
        HabitTemplate(id: "theme_ninja", title: String(localized: "Camino ninja"), iconKey: "dumbbell", order: 1, themeColorIndex: 10, themeKey: "ninja"),
        HabitTemplate(id: "theme_one_piece", title: String(localized: "Buscar el One Piece"), iconKey: "directions_walk", order: 2, themeColorIndex: 11, themeKey: "one_piece"),
        HabitTemplate(id: "theme_saiyan", title: String(localized: "Sé un saiyan"), iconKey: "self_improvement", order: 3, themeColorIndex: 3, themeKey: "saiyan"),
        HabitTemplate(id: "theme_pokemon", title: String(localized: "Sé un maestro Pokémon"), iconKey: "emoji_events", order: 4, themeColorIndex: 4, themeKey: "pokemon", isPremiumOnly: true),
        HabitTemplate(id: "theme_black_clover", title: String(localized: "Sé el Rey Mago"), iconKey: "local_fire_department", order: 5, themeColorIndex: 9, themeKey: "black_clover", isPremiumOnly: true)
    ]
}
