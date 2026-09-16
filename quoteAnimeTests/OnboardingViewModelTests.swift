import Foundation
import Testing
@testable import quoteAnime

/// The onboarding no longer owns the anime selection — that moved to Settings — so what has to
/// keep working is the rest of it: it marks itself completed and hands control back, with or
/// without a habit, and on iOS 16 (no `createHabitUseCase`) it must still finish instead of
/// stalling on a habit nothing can save.
@MainActor
@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {

    private static func makeGate(premium: Bool = false) -> (PremiumGate, String) {
        let suiteName = "test.onboarding.\(UUID().uuidString)"
        let gate = PremiumGate(defaults: UserDefaults(suiteName: suiteName)!)
        gate.isPremium = premium
        return (gate, suiteName)
    }

    private static func tearDown(_ suiteName: String) {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    // MARK: - Completing without a habit

    @Test("completar sin elegir hábito marca el onboarding y devuelve el control")
    func completesWithoutTemplate() async {
        let repository = FakeUserPreferencesRepository()
        let viewModel = OnboardingViewModel()
        var finished = false

        viewModel.setup(
            setOnboardingCompleted: SetOnboardingCompletedUseCase(repository: repository),
            createHabitUseCase: nil,
            onComplete: { finished = true }
        )
        viewModel.complete()

        #expect(finished)
        #expect(repository.isOnboardingCompleted())
    }

    @Test("completar no escribe preferencias de categorías (ya no es su responsabilidad)")
    func completeDoesNotTouchPreferences() async {
        let repository = FakeUserPreferencesRepository()
        let viewModel = OnboardingViewModel()

        viewModel.setup(
            setOnboardingCompleted: SetOnboardingCompletedUseCase(repository: repository),
            createHabitUseCase: nil,
            onComplete: {}
        )
        viewModel.complete()

        #expect(repository.saveCount == 0)
        #expect(repository.preferences.selectedCategoryIds.isEmpty)
    }

    @Test("'Saltar' completa igual que llegar al final")
    func skipCompletes() async {
        let repository = FakeUserPreferencesRepository()
        let viewModel = OnboardingViewModel()
        var finished = false

        viewModel.setup(
            setOnboardingCompleted: SetOnboardingCompletedUseCase(repository: repository),
            createHabitUseCase: nil,
            onComplete: { finished = true }
        )
        // "Saltar" is the same call, made from page 0.
        #expect(viewModel.currentPage == 0)
        viewModel.complete()

        #expect(finished)
        #expect(repository.onboardingWrites == [true])
    }

    // MARK: - Completing with a habit (iOS 17+)

    @Test("elegir un hábito lo crea antes de devolver el control")
    func completesWithTemplate() async throws {
        let (gate, suite) = Self.makeGate()
        defer { Self.tearDown(suite) }
        let habitRepository = FakeHabitRepository()
        let preferences = FakeUserPreferencesRepository()
        let viewModel = OnboardingViewModel()

        let template = try #require(viewModel.habitTemplates.first)

        await confirmation("onComplete se llama") { completed in
            viewModel.setup(
                setOnboardingCompleted: SetOnboardingCompletedUseCase(repository: preferences),
                createHabitUseCase: CreateHabitUseCase(repository: habitRepository, premiumGate: gate),
                onComplete: { completed() }
            )
            viewModel.selectTemplate(template.id)
            viewModel.complete()

            // `complete()` creates the habit in a Task; give it a turn to run.
            await Task.yield()
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        let habits = try await habitRepository.fetchActiveHabits()
        #expect(habits.count == 1)
        #expect(habits.first?.title == template.title)
        #expect(habits.first?.templateId == template.id)
        #expect(preferences.isOnboardingCompleted())
    }

    @Test("tocar dos veces el mismo hábito lo deselecciona")
    func tappingTemplateTwiceDeselects() {
        let viewModel = OnboardingViewModel()
        let template = viewModel.habitTemplates[0]

        viewModel.selectTemplate(template.id)
        #expect(viewModel.selectedTemplateId == template.id)

        viewModel.selectTemplate(template.id)
        #expect(viewModel.selectedTemplateId == nil)
    }

    @Test("la lista de hábitos del onboarding no ofrece plantillas premium")
    func onboardingTemplatesAreFreeOnly() {
        let viewModel = OnboardingViewModel()

        #expect(!viewModel.habitTemplates.isEmpty)
        #expect(viewModel.habitTemplates.allSatisfy { !$0.isPremiumOnly })
    }

    // MARK: - iOS 16: no habit creation available

    @Test("sin createHabitUseCase (iOS 16) el onboarding termina igual, no se cuelga")
    func completesWhenHabitCreationUnavailable() async {
        let preferences = FakeUserPreferencesRepository()
        let viewModel = OnboardingViewModel()
        var finished = false

        viewModel.setup(
            setOnboardingCompleted: SetOnboardingCompletedUseCase(repository: preferences),
            createHabitUseCase: nil,
            onComplete: { finished = true }
        )
        // Defensive: even if a template somehow got selected, completing must not stall.
        viewModel.selectTemplate(viewModel.habitTemplates[0].id)
        viewModel.complete()

        #expect(finished)
        #expect(preferences.isOnboardingCompleted())
    }
}
