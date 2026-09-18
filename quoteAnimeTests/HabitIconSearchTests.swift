import Foundation
import Testing
@testable import quoteAnime

/// The icon picker's search (Android `1d9e231`). The names come from the compiled catalog in a
/// pinned language, so these tests fail if a translation the search relies on goes missing.
@Suite("Buscador del selector de íconos")
struct HabitIconSearchTests {

    nonisolated static let spanish = Locale(identifier: "es")
    nonisolated static let english = Locale(identifier: "en")

    private func search(_ query: String, in locale: Locale) -> [HabitIconCategory] {
        HabitIconSearch.filter(HabitIcons.categories, query: query, locale: locale) { key in
            HabitIcons.localizedLabel(for: key, locale: locale)
        }
    }

    private func keys(_ categories: [HabitIconCategory]) -> [String] {
        categories.flatMap(\.keys)
    }

    // MARK: - Language

    @Test("busca por el nombre en español", arguments: [
        ("agua", "water_drop"),
        ("Tender la cama", "bed"),
        ("meditar", "self_improvement"),
    ])
    func findsBySpanishName(query: String, expectedKey: String) {
        #expect(keys(search(query, in: Self.spanish)).contains(expectedKey))
    }

    @Test("busca por el nombre en inglés", arguments: [
        ("water", "water_drop"),
        ("Make the bed", "bed"),
        ("meditate", "self_improvement"),
    ])
    func findsByEnglishName(query: String, expectedKey: String) {
        #expect(keys(search(query, in: Self.english)).contains(expectedKey))
    }

    @Test("busca en el idioma del usuario, no en el otro")
    func searchesOnlyTheUsersLanguage() {
        // "water" is not a substring of any Spanish name, and "agua" of no English one.
        #expect(search("water", in: Self.spanish).isEmpty)
        #expect(search("agua", in: Self.english).isEmpty)
    }

    @Test("no busca por la clave técnica ni por el título de la categoría")
    func ignoresKeysAndCategoryTitles() {
        // `water_drop` is a key, "Nutrición" a category title — neither is an icon's name.
        #expect(search("water_drop", in: Self.english).isEmpty)
        #expect(search("Nutrición", in: Self.spanish).isEmpty)
    }

    // MARK: - Normalisation

    @Test("sin distinguir tildes: \"musica\" encuentra \"Tocar música\"")
    func ignoresDiacritics() {
        #expect(keys(search("musica", in: Self.spanish)) == ["music_note"])
        #expect(keys(search("MÚSICA", in: Self.spanish)) == ["music_note"])
    }

    @Test("sin distinguir mayúsculas", arguments: ["CORRER", "correr", "CoRrEr"])
    func ignoresCase(query: String) {
        #expect(keys(search(query, in: Self.spanish)) == ["running"])
    }

    @Test("ignora los espacios alrededor de la búsqueda")
    func trimsWhitespace() {
        #expect(keys(search("  correr ", in: Self.spanish)) == ["running"])
    }

    // MARK: - Empty and no results

    @Test("vacío o en blanco devuelve todo", arguments: ["", "   ", "\n"])
    func blankReturnsEverything(query: String) {
        let result = search(query, in: Self.spanish)
        #expect(result.map(\.id) == HabitIcons.categories.map(\.id))
        #expect(keys(result) == HabitIcons.allKeys)
    }

    @Test("sin resultados devuelve vacío")
    func noMatchReturnsEmpty() {
        #expect(search("zzzz", in: Self.spanish).isEmpty)
        #expect(search("zzzz", in: Self.english).isEmpty)
    }

    // MARK: - Sections

    @Test("conserva la categoría con sólo sus íconos que coinciden, en su orden")
    func keepsMatchingSectionsInOrder() {
        // "Cocinar" (egg, Nutrición) and "Cocinar en casa" (kitchen, Hogar).
        let result = search("cocinar", in: Self.spanish)
        #expect(result.map(\.id) == ["nutrition", "home"])
        #expect(result.map(\.keys) == [["egg"], ["kitchen"]])
    }

    @Test("una categoría sin coincidencias desaparece")
    func dropsEmptySections() {
        let result = search("bici", in: Self.spanish)
        #expect(result.map(\.id) == ["physical"])
        #expect(result.first?.keys == ["cycling"])
    }
}
