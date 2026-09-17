import Foundation
import Testing
@testable import quoteAnime

/// The quote widget now shows only the animes the user chose, like Android's
/// `UpdateQuoteWidgetWorker`. A widget extension is a separate process that cannot read the app's
/// `UserDefaults.standard`, so the selection has to reach it through the App Group — and the
/// interesting part is not the copy but the *first* one: someone who picked their animes months
/// ago has the value only in `.standard`, and must not be silently reset to "all animes" by the
/// update that ships this.
///
/// (The filtering itself, `pick(from:matching:)`, lives in the extension and can't be imported
/// here. Its rule is the same one `QuoteCategoryFilterTests` pins for the app's feed:
/// `GetAllQuotesUseCase.filtered`.)
@Suite("Selección de animes compartida con el widget")
struct WidgetAnimeSelectionTests {

    private static let key = "pref_selected_category_ids"

    private struct Suites {
        let store: UserPreferencesStore
        let app: UserDefaults
        let shared: UserDefaults
        let appName: String
        let sharedName: String
    }

    /// A fresh pair of suites per test: one standing in for `UserDefaults.standard`, one for the
    /// App Group. Never the real ones — the real group is what the widgets on the simulator read.
    private static func makeSuites(
        seedAppSelection: [String]? = nil,
        seedSharedSelection: [String]? = nil
    ) -> Suites {
        let appName = "test.prefs.app.\(UUID().uuidString)"
        let sharedName = "test.prefs.group.\(UUID().uuidString)"
        let app = UserDefaults(suiteName: appName)!
        let shared = UserDefaults(suiteName: sharedName)!
        if let seedAppSelection { app.set(seedAppSelection, forKey: key) }
        if let seedSharedSelection { shared.set(seedSharedSelection, forKey: key) }
        return Suites(
            store: UserPreferencesStore(defaults: app, sharedDefaults: shared),
            app: app,
            shared: shared,
            appName: appName,
            sharedName: sharedName
        )
    }

    private static func tearDown(_ suites: Suites) {
        UserDefaults.standard.removePersistentDomain(forName: suites.appName)
        UserDefaults.standard.removePersistentDomain(forName: suites.sharedName)
    }

    private static func sharedSelection(_ suites: Suites) -> Set<String>? {
        guard let stored = suites.shared.stringArray(forKey: key) else { return nil }
        return Set(stored)
    }

    // MARK: - Mirroring on save

    @Test(
        "al guardar, la selección queda también en el App Group",
        arguments: [
            Set<String>(),
            Set(["Naruto"]),
            Set(["Naruto", "One Piece"]),
            Set(["Haikyuu!!", "Hunter x Hunter", "Vinland Saga"]),
        ]
    )
    func saveMirrorsSelection(selection: Set<String>) {
        let suites = Self.makeSuites()
        defer { Self.tearDown(suites) }

        var prefs = suites.store.load()
        prefs.selectedCategoryIds = selection
        suites.store.save(prefs)

        #expect(Self.sharedSelection(suites) == selection)
    }

    @Test("quitar animes también se refleja en el App Group")
    func clearingSelectionMirrors() {
        let suites = Self.makeSuites()
        defer { Self.tearDown(suites) }

        var prefs = suites.store.load()
        prefs.selectedCategoryIds = ["Naruto", "Bleach"]
        suites.store.save(prefs)
        #expect(Self.sharedSelection(suites) == ["Naruto", "Bleach"])

        prefs.selectedCategoryIds = []
        suites.store.save(prefs)

        // Empty, not absent: the widget reads that as "all animes", never as "no animes".
        #expect(Self.sharedSelection(suites) == [])
    }

    @Test("la frecuencia del widget se sigue compartiendo por App Group")
    func saveMirrorsWidgetFrequency() {
        let suites = Self.makeSuites()
        defer { Self.tearDown(suites) }

        var prefs = suites.store.load()
        prefs.widgetUpdateTimesPerDay = 6
        suites.store.save(prefs)

        #expect(suites.shared.integer(forKey: WidgetSharedKeys.widgetUpdateTimesPerDay) == 6)
    }

    // MARK: - The migration

    /// The case this whole mechanism exists for.
    @Test("quien ya tenía animes elegidos los conserva: se copian al App Group")
    func existingSelectionIsMigrated() {
        let suites = Self.makeSuites(seedAppSelection: ["Naruto", "One Piece"])
        defer { Self.tearDown(suites) }

        #expect(Self.sharedSelection(suites) == ["Naruto", "One Piece"])
        // And the app's own copy is untouched by the migration.
        #expect(suites.store.load().selectedCategoryIds == ["Naruto", "One Piece"])
    }

    @Test("quien había elegido 'Todos' (selección vacía) también se migra tal cual")
    func explicitlyEmptySelectionIsMigrated() {
        let suites = Self.makeSuites(seedAppSelection: [])
        defer { Self.tearDown(suites) }

        #expect(Self.sharedSelection(suites) == [])
    }

    @Test("quien nunca eligió nada no deja nada escrito en el App Group")
    func neverChosenLeavesNothing() {
        let suites = Self.makeSuites()
        defer { Self.tearDown(suites) }

        #expect(Self.sharedSelection(suites) == nil)
        // Which the widget reads as "all animes" all the same.
        #expect(suites.store.load().selectedCategoryIds.isEmpty)
    }

    /// The migration must not run twice: on a later launch the App Group already holds the value,
    /// and re-copying from `.standard` would be harmless today but wrong the moment anything else
    /// writes to the group.
    @Test("si el App Group ya tenía la selección, la migración no la pisa")
    func migrationDoesNotOverwrite() {
        let suites = Self.makeSuites(
            seedAppSelection: ["Naruto"],
            seedSharedSelection: ["Bleach", "Death Note"]
        )
        defer { Self.tearDown(suites) }

        #expect(Self.sharedSelection(suites) == ["Bleach", "Death Note"])
    }

    @Test("una segunda instancia del store no vuelve a migrar")
    func migrationIsIdempotent() {
        let suites = Self.makeSuites(seedAppSelection: ["Naruto"])
        defer { Self.tearDown(suites) }

        // The group got the value on the first init; now the app's copy changes behind its back
        // (it can't, in practice — this just proves the second init doesn't re-copy).
        suites.app.set(["Bleach"], forKey: Self.key)
        _ = UserPreferencesStore(defaults: suites.app, sharedDefaults: suites.shared)

        #expect(Self.sharedSelection(suites) == ["Naruto"])
    }

    // MARK: - Boundaries

    @Test("sin App Group disponible, guardar no explota")
    func missingAppGroupIsSurvivable() {
        let appName = "test.prefs.app.\(UUID().uuidString)"
        let app = UserDefaults(suiteName: appName)!
        defer { UserDefaults.standard.removePersistentDomain(forName: appName) }
        let store = UserPreferencesStore(defaults: app, sharedDefaults: nil)

        var prefs = store.load()
        prefs.selectedCategoryIds = ["Naruto"]
        store.save(prefs)

        #expect(store.load().selectedCategoryIds == ["Naruto"])
    }

    @Test("los nombres viajan exactos: el id es el nombre del anime")
    func namesTravelVerbatim() {
        let suites = Self.makeSuites()
        defer { Self.tearDown(suites) }

        let selection: Set<String> = ["Haikyuu!!", "Fullmetal Alchemist", "Hunter x Hunter", "JoJo's Bizarre Adventure"]
        var prefs = suites.store.load()
        prefs.selectedCategoryIds = selection
        suites.store.save(prefs)

        #expect(Self.sharedSelection(suites) == selection)
    }
}
