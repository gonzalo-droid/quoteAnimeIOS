import Foundation

struct HabitTemplate: Identifiable, Hashable {
    let id: String
    let title: String
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

/// Bundled fallback — same 5 themes Android ships, same 2 locked behind Premium (Pokémon,
/// Black Clover). The original 3 stay free so no existing user loses anything.
enum DefaultHabitTemplates {
    static let all: [HabitTemplate] = [
        HabitTemplate(id: "theme_ninja", title: "Camino ninja", iconKey: "figure.strengthtraining.traditional", order: 1, themeColorIndex: 10, themeKey: "ninja"),
        HabitTemplate(id: "theme_one_piece", title: "Buscar el One Piece", iconKey: "figure.walk", order: 2, themeColorIndex: 11, themeKey: "one_piece"),
        HabitTemplate(id: "theme_saiyan", title: "Sé un saiyan", iconKey: "figure.mind.and.body", order: 3, themeColorIndex: 3, themeKey: "saiyan"),
        HabitTemplate(id: "theme_pokemon", title: "Sé un maestro Pokémon", iconKey: "sportscourt", order: 4, themeColorIndex: 4, themeKey: "pokemon", isPremiumOnly: true),
        HabitTemplate(id: "theme_black_clover", title: "Sé el Rey Mago", iconKey: "sparkles", order: 5, themeColorIndex: 7, themeKey: "black_clover", isPremiumOnly: true)
    ]
}
