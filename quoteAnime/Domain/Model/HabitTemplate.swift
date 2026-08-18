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
}

/// Bundled fallback, same 3 free themes Android shipped before Premium existed — the two
/// newer ones (Pokémon, Black Clover) are premium-exclusive on Android, so they're deferred
/// to whenever iOS Premium gets built too, rather than shipping them free here first.
enum DefaultHabitTemplates {
    static let all: [HabitTemplate] = [
        HabitTemplate(id: "theme_ninja", title: "Camino ninja", iconKey: "figure.strengthtraining.traditional", order: 1, themeColorIndex: 10, themeKey: "ninja"),
        HabitTemplate(id: "theme_one_piece", title: "Buscar el One Piece", iconKey: "figure.walk", order: 2, themeColorIndex: 11, themeKey: "one_piece"),
        HabitTemplate(id: "theme_saiyan", title: "Sé un saiyan", iconKey: "figure.mind.and.body", order: 3, themeColorIndex: 3, themeKey: "saiyan")
    ]
}
