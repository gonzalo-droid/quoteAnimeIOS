import Foundation
import Testing
@testable import quoteAnime

/// Persistence round-trip for the anime selection. It is stored as a `[String]` under
/// `pref_selected_category_ids` and read back as a `Set`, so order must not matter and an
/// absent key must mean "all animes" (empty set), never "no animes".
@Suite("UserPreferencesStore")
struct UserPreferencesStoreTests {

    private static func makeStore() -> (UserPreferencesStore, UserDefaults, String) {
        let suiteName = "test.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (UserPreferencesStore(defaults: defaults), defaults, suiteName)
    }

    private static func tearDown(_ suiteName: String) {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Round trip

    @Test(
        "la selección de animes sobrevive el guardado y la lectura",
        arguments: [
            Set<String>(),
            Set(["Naruto"]),
            Set(["Naruto", "One Piece"]),
            Set(["Naruto", "One Piece", "Vinland Saga", "Bleach", "Haikyuu!!"]),
        ]
    )
    func selectionRoundTrips(selection: Set<String>) {
        let (store, _, suite) = Self.makeStore()
        defer { Self.tearDown(suite) }

        var prefs = store.load()
        prefs.selectedCategoryIds = selection
        store.save(prefs)

        #expect(store.load().selectedCategoryIds == selection)
    }

    @Test("un anime con espacios y signos en el nombre se guarda tal cual")
    func selectionKeepsExactNames() {
        let (store, _, suite) = Self.makeStore()
        defer { Self.tearDown(suite) }

        let selection: Set<String> = ["Haikyuu!!", "Fullmetal Alchemist", "Hunter x Hunter"]
        var prefs = store.load()
        prefs.selectedCategoryIds = selection
        store.save(prefs)

        #expect(store.load().selectedCategoryIds == selection)
    }

    // MARK: - Defaults and boundaries

    @Test("sin nada guardado, la selección arranca vacía = todos los animes")
    func defaultSelectionIsEmpty() {
        let (store, _, suite) = Self.makeStore()
        defer { Self.tearDown(suite) }

        #expect(store.load().selectedCategoryIds.isEmpty)
    }

    @Test("volver a 'Todos' borra la selección anterior")
    func clearingSelectionPersists() {
        let (store, _, suite) = Self.makeStore()
        defer { Self.tearDown(suite) }

        var prefs = store.load()
        prefs.selectedCategoryIds = ["Naruto", "One Piece"]
        store.save(prefs)
        #expect(store.load().selectedCategoryIds.count == 2)

        prefs.selectedCategoryIds = []
        store.save(prefs)

        #expect(store.load().selectedCategoryIds.isEmpty)
    }

    @Test("guardar la selección no pisa el resto de las preferencias")
    func savingSelectionKeepsOtherPreferences() {
        let (store, _, suite) = Self.makeStore()
        defer { Self.tearDown(suite) }

        var prefs = store.load()
        prefs.notificationsEnabled = true
        prefs.notificationStartHour = 9
        prefs.notificationEndHour = 21
        prefs.notificationFrequency = 5
        prefs.widgetUpdateTimesPerDay = 6
        store.save(prefs)

        prefs.selectedCategoryIds = ["Naruto"]
        store.save(prefs)

        let loaded = store.load()
        #expect(loaded.selectedCategoryIds == ["Naruto"])
        #expect(loaded.notificationsEnabled)
        #expect(loaded.notificationStartHour == 9)
        #expect(loaded.notificationEndHour == 21)
        #expect(loaded.notificationFrequency == 5)
        #expect(loaded.widgetUpdateTimesPerDay == 6)
    }

    @Test("la selección se guarda en la key pref_selected_category_ids")
    func selectionUsesTheExpectedKey() {
        let (store, defaults, suite) = Self.makeStore()
        defer { Self.tearDown(suite) }

        var prefs = store.load()
        prefs.selectedCategoryIds = ["Naruto", "One Piece"]
        store.save(prefs)

        let stored = defaults.stringArray(forKey: "pref_selected_category_ids") ?? []
        #expect(Set(stored) == ["Naruto", "One Piece"])
    }

    @Test("el onboarding completado se persiste por separado")
    func onboardingFlagRoundTrips() {
        let (store, _, suite) = Self.makeStore()
        defer { Self.tearDown(suite) }

        #expect(store.isOnboardingCompleted == false)
        store.isOnboardingCompleted = true
        #expect(store.isOnboardingCompleted)
    }
}
