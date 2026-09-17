import Foundation
import Testing
@testable import quoteAnime

/// Templates used to store SF Symbol names as `iconKey`, which `HabitIcons` didn't know, so
/// habits created from them showed the generic check. These pin the fix and the recovery of the
/// habits that were already saved with the broken value.
@Suite("Íconos de hábitos")
struct HabitIconKeyTests {

    private static let fallbackSymbol = "checkmark.circle.fill"

    /// Same keys as Android's `DefaultHabitTemplates.kt`.
    @Test(
        "cada plantilla usa la clave estable de Android",
        arguments: [
            ("theme_ninja", "dumbbell"),
            ("theme_one_piece", "directions_walk"),
            ("theme_saiyan", "self_improvement"),
            ("theme_pokemon", "emoji_events"),
            ("theme_black_clover", "local_fire_department"),
        ]
    )
    func templateUsesAndroidKey(templateId: String, expectedKey: String) throws {
        let template = try #require(DefaultHabitTemplates.all.first { $0.id == templateId })
        #expect(template.iconKey == expectedKey)
    }

    @Test("ninguna plantilla cae en el ícono genérico")
    func everyTemplateHasAThemedIcon() {
        for template in DefaultHabitTemplates.all {
            #expect(HabitIcons.allKeys.contains(template.iconKey), "\(template.id): \(template.iconKey)")
            #expect(HabitIcons.symbol(for: template.iconKey) != Self.fallbackSymbol, "\(template.id)")
        }
    }

    @Test(
        "las claves viejas de plantilla se traducen a la clave estable",
        arguments: [
            ("figure.strengthtraining.traditional", "dumbbell", "dumbbell.fill"),
            ("figure.walk", "directions_walk", "figure.walk"),
            ("figure.mind.and.body", "self_improvement", "figure.mind.and.body"),
            ("sportscourt", "emoji_events", "trophy.fill"),
            ("sparkles", "local_fire_department", "flame.fill"),
        ]
    )
    func legacyKeyResolves(legacy: String, stable: String, symbol: String) {
        #expect(HabitIconAliases.canonical(legacy) == stable)
        #expect(HabitIcons.symbol(for: legacy) == symbol)
        #expect(HabitIcons.isKnown(legacy))
    }

    @Test("una clave estable no se toca", arguments: ["dumbbell", "cleaning", "flag", "book"])
    func stableKeyPassesThrough(key: String) {
        #expect(HabitIconAliases.canonical(key) == key)
    }

    /// If a legacy name ever became a stable key, the alias would silently repaint every habit
    /// that picked it on purpose.
    @Test("ningún alias pisa una clave estable y todos apuntan a una existente")
    func aliasesAreSafe() {
        for (legacy, stable) in HabitIconAliases.legacyToStable {
            #expect(!HabitIcons.allKeys.contains(legacy), "\(legacy) es una clave estable")
            #expect(HabitIcons.allKeys.contains(stable), "\(stable) no existe en HabitIcons")
        }
    }

    @Test("una clave desconocida sigue mostrando el ícono genérico")
    func unknownKeyFallsBack() {
        #expect(HabitIcons.symbol(for: "leaf") == Self.fallbackSymbol)
        #expect(!HabitIcons.isKnown("leaf"))
        #expect(!HabitIcons.isKnown(""))
    }

    /// A habit stored with the broken key comes out of SwiftData already corrected, so the editor
    /// highlights the right icon and the next save writes the stable key back.
    @available(iOS 17, *)
    @Test("un hábito guardado con la clave rota se lee con la clave estable")
    func storedLegacyKeyIsNormalisedOnRead() {
        let broken = HabitFixture.make(id: "old", iconKey: "sportscourt")
        let model = HabitModel(from: broken)
        #expect(model.iconKey == "sportscourt")

        let habit = model.toDomain()
        #expect(habit.iconKey == "emoji_events")

        model.apply(habit)
        #expect(model.iconKey == "emoji_events")
    }

    @available(iOS 17, *)
    @Test("un hábito con clave estable se lee igual")
    func storedStableKeyIsUntouched() {
        let model = HabitModel(from: HabitFixture.make(iconKey: "book"))
        #expect(model.toDomain().iconKey == "book")
    }
}
