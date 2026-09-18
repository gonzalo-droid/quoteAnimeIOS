import Foundation
import Testing
import UIKit
@testable import quoteAnime

/// Cover art of the themed suggestions (Android `923e552`, `3153211`, `64f9b8b`).
@Suite("Portadas de las plantillas")
@MainActor
struct HabitThemeCoverTests {

    private func settle() async {
        for _ in 0..<300 { await Task.yield() }
    }

    // MARK: - Resolution

    @Test("cada plantilla resuelve una portada que existe en el catálogo de assets",
          arguments: DefaultHabitTemplates.all)
    func everyTemplateHasACover(template: HabitTemplate) throws {
        let asset = try #require(HabitThemeImages.assetName(for: template.themeKey))
        #expect(UIImage(named: asset) != nil, "Falta \(asset) en Assets.xcassets")
    }

    @Test("cada tema con portada existe en el catálogo", arguments: HabitThemeImages.themeKeys)
    func everyThemeKeyResolves(themeKey: String) throws {
        let asset = try #require(HabitThemeImages.assetName(for: themeKey))
        #expect(UIImage(named: asset) != nil)
    }

    /// The keys are persisted on `Habit.coverAnimeSlug` and are Android's own values: renaming
    /// one would strip existing habits of their cover.
    @Test("las claves de tema son las de Android")
    func themeKeysMatchAndroid() {
        #expect(Set(HabitThemeImages.themeKeys) == ["ninja", "one_piece", "saiyan", "pokemon", "black_clover"])
        #expect(Set(DefaultHabitTemplates.all.compactMap(\.themeKey)) == Set(HabitThemeImages.themeKeys))
    }

    @Test("sin tema o con una clave desconocida no hay portada ni descripción", arguments: [nil, "", "bleach"] as [String?])
    func unknownThemeHasNoCover(themeKey: String?) {
        #expect(HabitThemeImages.assetName(for: themeKey) == nil)
        #expect(HabitThemeImages.description(for: themeKey) == nil)
    }

    @Test("cada plantilla trae su descripción temática", arguments: DefaultHabitTemplates.all)
    func everyTemplateHasADescription(template: HabitTemplate) {
        #expect(HabitThemeImages.description(for: template.themeKey)?.isEmpty == false)
    }

    // MARK: - Editor

    private func makeEditor(habitId: String? = nil, seed: [Habit] = []) -> (HabitEditorViewModel, FakeHabitRepository) {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: seed)
        let viewModel = HabitEditorViewModel(
            habitId: habitId,
            createHabitUseCase: CreateHabitUseCase(
                repository: repository, premiumGate: PremiumGate.fake(), calendar: TestCalendar.fixed
            ),
            updateHabitUseCase: UpdateHabitUseCase(repository: repository, calendar: TestCalendar.fixed),
            habitRepository: repository,
            habitReminderScheduler: FakeHabitReminderScheduler(),
            routineWidgetRefresher: FakeRoutineWidgetRefresher()
        )
        return (viewModel, repository)
    }

    @Test("elegir una sugerencia aplica su título, descripción, ícono, color y portada")
    func selectingATemplateAppliesIt() throws {
        let (viewModel, _) = makeEditor()
        let template = try #require(DefaultHabitTemplates.all.first { $0.themeKey == "one_piece" })
        viewModel.uiState.title = "Algo que escribí"

        viewModel.onTemplateSelected(template)

        #expect(viewModel.uiState.templateId == template.id)
        #expect(viewModel.uiState.themeKey == "one_piece")
        #expect(viewModel.uiState.title == template.title)
        #expect(viewModel.uiState.description == HabitThemeImages.description(for: "one_piece"))
        #expect(viewModel.uiState.iconKey == template.iconKey)
        #expect(viewModel.uiState.colorIndex == template.themeColorIndex)
    }

    @Test("el hábito creado desde una sugerencia guarda su portada")
    func savedHabitKeepsItsCover() async throws {
        let (viewModel, repository) = makeEditor()
        let template = try #require(DefaultHabitTemplates.all.first)

        viewModel.onTemplateSelected(template)
        viewModel.save {}
        await settle()

        let saved = try #require(try await repository.fetchActiveHabits().first)
        #expect(saved.coverAnimeSlug == template.themeKey)
        #expect(saved.templateId == template.id)
    }

    @Test("un hábito propio no tiene portada")
    func customHabitHasNoCover() async throws {
        let (viewModel, repository) = makeEditor()
        viewModel.uiState.title = "Leer"

        viewModel.save {}
        await settle()

        let saved = try #require(try await repository.fetchActiveHabits().first)
        #expect(saved.coverAnimeSlug == nil)
    }

    @Test("editar un hábito con portada la conserva")
    func editingKeepsTheCover() async throws {
        var habit = HabitFixture.make(id: "h", title: "Camino ninja")
        habit.templateId = "theme_ninja"
        habit.coverAnimeSlug = "ninja"
        let (viewModel, repository) = makeEditor(habitId: "h", seed: [habit])
        viewModel.onAppear()
        await settle()
        #expect(viewModel.uiState.themeKey == "ninja")

        viewModel.uiState.title = "Camino ninja diario"
        viewModel.save {}
        await settle()

        let saved = try #require(try await repository.fetchHabit(id: "h"))
        #expect(saved.coverAnimeSlug == "ninja")
        #expect(saved.templateId == "theme_ninja")
    }

    // MARK: - Default suggestion (64f9b8b)

    @Test("un hábito nuevo arranca con la primera sugerencia que el usuario puede usar", arguments: [false, true])
    func newHabitStartsFromFirstUsableTemplate(isPremium: Bool) throws {
        let (viewModel, _) = makeEditor()
        let first = try #require(DefaultHabitTemplates.all.first { !$0.isLocked(isPremium: isPremium) })

        viewModel.applyDefaultTemplate(from: DefaultHabitTemplates.all, isPremium: isPremium)

        #expect(viewModel.uiState.templateId == first.id)
        #expect(viewModel.uiState.themeKey == first.themeKey)
    }

    @Test("nunca aplica una sugerencia con candado")
    func neverAppliesALockedTemplate() throws {
        let (viewModel, _) = makeEditor()
        let lockedOnly = DefaultHabitTemplates.all.filter(\.isPremiumOnly)

        viewModel.applyDefaultTemplate(from: lockedOnly, isPremium: false)

        #expect(viewModel.uiState.templateId == nil)
    }

    @Test("no pisa una sugerencia ya elegida ni un hábito que se está editando")
    func defaultNeverOverridesAChoice() async throws {
        let (viewModel, _) = makeEditor()
        let saiyan = try #require(DefaultHabitTemplates.all.first { $0.themeKey == "saiyan" })
        viewModel.onTemplateSelected(saiyan)
        viewModel.applyDefaultTemplate(from: DefaultHabitTemplates.all, isPremium: false)
        #expect(viewModel.uiState.templateId == saiyan.id)

        let habit = HabitFixture.make(id: "h", title: "Leer")
        let (editing, _) = makeEditor(habitId: "h", seed: [habit])
        editing.onAppear()
        await settle()
        editing.applyDefaultTemplate(from: DefaultHabitTemplates.all, isPremium: false)
        #expect(editing.uiState.templateId == nil)
        #expect(editing.uiState.title == "Leer")
    }

    // MARK: - Onboarding

    @Test("el hábito elegido en el onboarding guarda su portada y su descripción")
    func onboardingHabitKeepsItsCover() async throws {
        let repository = FakeHabitRepository()
        let viewModel = OnboardingViewModel()
        let template = try #require(viewModel.habitTemplates.first)

        await confirmation("onComplete se llama") { completed in
            viewModel.setup(
                setOnboardingCompleted: SetOnboardingCompletedUseCase(repository: FakeUserPreferencesRepository()),
                createHabitUseCase: CreateHabitUseCase(repository: repository, premiumGate: PremiumGate.fake()),
                onComplete: { completed() }
            )
            viewModel.selectTemplate(template.id)
            #expect(viewModel.selectedTemplate?.id == template.id)
            viewModel.complete()
            await Task.yield()
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        let saved = try #require(try await repository.fetchActiveHabits().first)
        #expect(saved.coverAnimeSlug == template.themeKey)
        #expect(saved.description == HabitThemeImages.description(for: template.themeKey))
    }
}
