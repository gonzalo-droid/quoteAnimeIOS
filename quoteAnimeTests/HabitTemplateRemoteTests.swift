import Foundation
import Testing
@testable import quoteAnime

/// Android `492f80f`: suggestions from `/habitTemplates` in the Realtime Database, falling back to
/// the bundled list. Mirrors `GetHabitTemplatesUseCaseTest` (sorted by order, empty node, remote
/// failure) and adds what only a port has to decide: Android keys as titles, values of the wrong
/// type, and keys or icons this build doesn't know.
@MainActor
@Suite("Plantillas de hábito remotas")
struct HabitTemplateRemoteTests {

    // MARK: - DTO

    @Test("un nodo completo se decodifica entero")
    func decodesFullNode() throws {
        let dto = try #require(HabitTemplateDTO(key: "theme_bleach", value: [
            "title": "template_theme_ninja",
            "iconKey": "dumbbell",
            "order": 7,
            "themeColorIndex": 3,
            "themeKey": "ninja",
            "isPremiumOnly": true,
        ] as [String: Any]))

        #expect(dto == HabitTemplateDTO(
            id: "theme_bleach", title: "template_theme_ninja", iconKey: "dumbbell",
            order: 7, themeColorIndex: 3, themeKey: "ninja", isPremiumOnly: true
        ))
    }

    @Test("los opcionales ausentes toman los valores de Android")
    func optionalsDefault() throws {
        let dto = try #require(HabitTemplateDTO(key: "read", value: [
            "title": "template_read",
            "iconKey": "book",
        ] as [String: Any]))

        #expect(dto.order == 0)
        #expect(dto.themeColorIndex == nil)
        #expect(dto.themeKey == nil)
        #expect(dto.isPremiumOnly == false)
    }

    @Test("sin título o sin ícono la plantilla se descarta", arguments: [
        ["iconKey": "book"],
        ["title": "template_read"],
        ["title": "template_read", "iconKey": ""],
        ["title": 42, "iconKey": "book"],
    ] as [[String: Any]])
    func requiredFieldsMissing(value: [String: Any]) {
        #expect(HabitTemplateDTO(key: "x", value: value) == nil)
    }

    @Test("un nodo hijo que no es un objeto se descarta")
    func childNotAnObject() {
        #expect(HabitTemplateDTO(key: "x", value: "template_read") == nil)
    }

    @Test("orden o color de tipo inválido caen al valor por defecto")
    func invalidOptionalTypes() throws {
        let dto = try #require(HabitTemplateDTO(key: "x", value: [
            "title": "template_read", "iconKey": "book", "order": "primero", "themeColorIndex": "rojo",
        ] as [String: Any]))

        #expect(dto.order == 0)
        #expect(dto.themeColorIndex == nil)
    }

    @Test("isPremiumOnly de tipo inválido descarta la plantilla: nunca regala un tema premium")
    func invalidPremiumFlagDrops() {
        let value: [String: Any] = ["title": "template_theme_pokemon", "iconKey": "emoji_events", "isPremiumOnly": "yes"]
        #expect(HabitTemplateDTO(key: "x", value: value) == nil)
    }

    @Test("el nodo llega como diccionario, como arreglo con huecos, o no llega")
    func decodesNodeShapes() {
        let dict: [String: Any] = [
            "a": ["title": "template_read", "iconKey": "book"],
            "b": ["title": "template_walk", "iconKey": "directions_walk"],
        ]
        #expect(Set(HabitTemplateDTO.decodeNode(dict).map(\.id)) == ["a", "b"])

        let array: [Any] = [NSNull(), ["title": "template_read", "iconKey": "book"]]
        #expect(HabitTemplateDTO.decodeNode(array).map(\.id) == ["1"])

        #expect(HabitTemplateDTO.decodeNode(NSNull()).isEmpty)
        #expect(HabitTemplateDTO.decodeNode(nil).isEmpty)
    }

    @Test("un color fuera de la paleta no se guarda")
    func colorOutsidePalette() throws {
        let dto = HabitTemplateDTO(id: "x", title: "template_read", iconKey: "book", themeColorIndex: 99)
        let template = try #require(dto.toDomain(paletteSize: HabitPalette.colors.count))
        #expect(template.themeColorIndex == nil)
    }

    // MARK: - Titles

    @Test("cada clave de Android conocida da un título legible")
    func knownKeysResolve() {
        for key in HabitTemplateTitles.knownKeys {
            let title = HabitTemplateTitles.displayTitle(for: key)
            #expect(title != nil, "\(key)")
            #expect(title != key)
        }
    }

    @Test("las claves de las cinco plantillas locales dan sus mismos títulos")
    func keysMatchBundledTitles() {
        let bundledTitleByKey = [
            "template_theme_ninja": "theme_ninja",
            "template_theme_one_piece": "theme_one_piece",
            "template_theme_saiyan": "theme_saiyan",
            "template_theme_pokemon": "theme_pokemon",
            "template_theme_black_clover": "theme_black_clover",
        ]
        for (key, id) in bundledTitleByKey {
            let bundled = DefaultHabitTemplates.all.first { $0.id == id }?.title
            #expect(HabitTemplateTitles.displayTitle(for: key) == bundled, "\(key)")
        }
    }

    @Test("el título se resuelve en el idioma del usuario", arguments: [("es", "Camino ninja"), ("en", "Ninja path")])
    func titleIsLocalized(language: String, expected: String) {
        var resource = LocalizedStringResource("Camino ninja")
        resource.locale = Locale(identifier: language)
        #expect(String(localized: resource) == expected)
    }

    @Test("una clave desconocida nunca llega a la pantalla", arguments: [
        "template_theme_bleach", "habit_new_one", "template_x2",
    ])
    func unknownKeyIsDropped(key: String) {
        #expect(HabitTemplateTitles.displayTitle(for: key) == nil)
        #expect(HabitTemplateDTO(id: "x", title: key, iconKey: "book").toDomain(paletteSize: 14) == nil)
    }

    @Test("un título literal se muestra tal cual, como en Android", arguments: [
        "Leer 20 minutos", "leer", "Caminar al sol",
    ])
    func literalTitleShown(title: String) {
        #expect(HabitTemplateTitles.displayTitle(for: title) == title)
    }

    @Test("un título en blanco se descarta")
    func blankTitle() {
        #expect(HabitTemplateTitles.displayTitle(for: "   ") == nil)
    }

    // MARK: - Icons

    @Test("un ícono que iOS no conoce cae al genérico sin romper")
    func unknownIconFallsBack() throws {
        let template = try #require(
            HabitTemplateDTO(id: "x", title: "template_read", iconKey: "sword_of_the_future")
                .toDomain(paletteSize: 14)
        )
        #expect(template.iconKey == "sword_of_the_future")
        #expect(HabitIcons.isKnown(template.iconKey) == false)
        #expect(HabitIcons.symbol(for: template.iconKey) == "checkmark.circle.fill")
    }

    @Test("un ícono con alias viejo resuelve a su glifo")
    func legacyIconAlias() {
        #expect(HabitIcons.symbol(for: "figure.walk") == HabitIcons.symbol(for: "directions_walk"))
    }

    // MARK: - Use case

    @Test("las remotas llegan ordenadas por order")
    func sortedByOrder() async {
        let remote = FakeHabitTemplateRemoteSource([
            HabitTemplateDTO(id: "b", title: "template_read", iconKey: "book", order: 2),
            HabitTemplateDTO(id: "a", title: "template_train", iconKey: "dumbbell", order: 1),
            HabitTemplateDTO(id: "c", title: "template_walk", iconKey: "directions_walk", order: 2),
        ])
        let templates = await GetHabitTemplatesUseCase(remote: remote).execute()
        #expect(templates.map(\.id) == ["a", "b", "c"])
        #expect(templates.first?.title == String(localized: "Entrenar"))
    }

    @Test("nodo vacío o ausente: las locales")
    func emptyNodeFallsBack() async {
        let templates = await GetHabitTemplatesUseCase(remote: FakeHabitTemplateRemoteSource([])).execute()
        #expect(templates == DefaultHabitTemplates.all)
    }

    @Test("error de red: las locales")
    func networkErrorFallsBack() async {
        let templates = await GetHabitTemplatesUseCase(remote: FakeHabitTemplateRemoteSource(error: FakeHabitTemplateRemoteSource.Offline())).execute()
        #expect(templates == DefaultHabitTemplates.all)
    }

    @Test("si todas las remotas son inválidas: las locales")
    func allInvalidFallsBack() async {
        let remote = FakeHabitTemplateRemoteSource([
            HabitTemplateDTO(id: "x", title: "template_theme_bleach", iconKey: "book"),
        ])
        let templates = await GetHabitTemplatesUseCase(remote: remote).execute()
        #expect(templates == DefaultHabitTemplates.all)
    }

    @Test("una clave desconocida se descarta y el resto sigue")
    func unknownKeyAmongValid() async {
        let remote = FakeHabitTemplateRemoteSource([
            HabitTemplateDTO(id: "new", title: "template_theme_bleach", iconKey: "book", order: 1),
            HabitTemplateDTO(id: "read", title: "template_read", iconKey: "book", order: 2),
        ])
        let templates = await GetHabitTemplatesUseCase(remote: remote).execute()
        #expect(templates.map(\.id) == ["read"])
    }

    @Test("sin fuente remota: sólo las locales, sin esperar nada")
    func noRemote() async {
        let useCase = GetHabitTemplatesUseCase()
        #expect(useCase.bundled == DefaultHabitTemplates.all)
        #expect(await useCase.execute() == DefaultHabitTemplates.all)
    }
}
