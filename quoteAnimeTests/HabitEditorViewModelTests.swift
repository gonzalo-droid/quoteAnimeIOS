import Foundation
import Testing
@testable import quoteAnime

/// The editor's job around the new end date is to never hand the use cases an inverted range:
/// the picker is bounded, and moving the start past the end drags the end along.
@Suite("HabitEditorViewModel")
@MainActor
struct HabitEditorViewModelTests {

    private static func makeSUT(
        habitId: String? = nil,
        seed: [Habit] = [],
        reminderScheduler: FakeHabitReminderScheduler = FakeHabitReminderScheduler()
    ) -> (HabitEditorViewModel, FakeHabitRepository, String) {
        let suiteName = "test.habiteditor.\(UUID().uuidString)"
        let gate = PremiumGate(defaults: UserDefaults(suiteName: suiteName)!)
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: seed)
        let viewModel = HabitEditorViewModel(
            habitId: habitId,
            createHabitUseCase: CreateHabitUseCase(
                repository: repository, premiumGate: gate, calendar: TestCalendar.fixed
            ),
            updateHabitUseCase: UpdateHabitUseCase(repository: repository, calendar: TestCalendar.fixed),
            habitRepository: repository,
            habitReminderScheduler: reminderScheduler
        )
        return (viewModel, repository, suiteName)
    }

    private static func tearDown(_ suiteName: String) {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func settle() async {
        for _ in 0..<200 { await Task.yield() }
    }

    // MARK: - End date opt-in

    @Test("por defecto no hay fecha de fin")
    func endDateIsOptOutByDefault() {
        let (viewModel, _, suite) = Self.makeSUT()
        defer { Self.tearDown(suite) }

        #expect(viewModel.uiState.hasEndDate == false)
    }

    @Test("al activar la fecha de fin nunca queda antes de la de inicio")
    func enablingEndDateClampsIt() {
        let (viewModel, _, suite) = Self.makeSUT()
        defer { Self.tearDown(suite) }

        viewModel.uiState.startDate = TestCalendar.day(0)
        viewModel.uiState.endDate = TestCalendar.day(-10)

        viewModel.onEndDateEnabled(true)

        #expect(viewModel.uiState.endDate >= viewModel.uiState.startDate)
    }

    @Test("mover la fecha de inicio más allá del fin arrastra el fin", arguments: [1, 5, 40])
    func movingStartPastEndDragsEnd(offset: Int) {
        let (viewModel, _, suite) = Self.makeSUT()
        defer { Self.tearDown(suite) }

        viewModel.uiState.startDate = TestCalendar.day(0)
        viewModel.onEndDateEnabled(true)
        viewModel.uiState.endDate = TestCalendar.day(0)

        viewModel.onStartDateChanged(TestCalendar.day(offset))

        #expect(viewModel.uiState.endDate == TestCalendar.day(offset))
    }

    @Test("mover la fecha de inicio hacia atrás no toca el fin")
    func movingStartBackLeavesEndAlone() {
        let (viewModel, _, suite) = Self.makeSUT()
        defer { Self.tearDown(suite) }

        viewModel.uiState.startDate = TestCalendar.day(0)
        viewModel.onEndDateEnabled(true)
        viewModel.uiState.endDate = TestCalendar.day(10)

        viewModel.onStartDateChanged(TestCalendar.day(-5))

        #expect(viewModel.uiState.endDate == TestCalendar.day(10))
    }

    @Test("sin fecha de fin activada, mover el inicio no toca nada más")
    func movingStartWithoutEndDateIsInert() {
        let (viewModel, _, suite) = Self.makeSUT()
        defer { Self.tearDown(suite) }

        viewModel.uiState.endDate = TestCalendar.day(-100)

        viewModel.onStartDateChanged(TestCalendar.day(0))

        #expect(viewModel.uiState.endDate == TestCalendar.day(-100), "el valor guardado del picker apagado no se usa")
    }

    // MARK: - Saving

    @Test("guardar sin fecha de fin deja el hábito indefinido")
    func savingWithoutEndDateLeavesItNil() async {
        let (viewModel, repository, suite) = Self.makeSUT()
        defer { Self.tearDown(suite) }

        viewModel.uiState.title = "Meditar"
        viewModel.save(onSaved: {})
        await settle()

        let saved = try! await repository.fetchActiveHabits().first
        #expect(saved?.endDate == nil)
    }

    @Test("guardar con fecha de fin la persiste")
    func savingWithEndDatePersistsIt() async {
        let (viewModel, repository, suite) = Self.makeSUT()
        defer { Self.tearDown(suite) }

        viewModel.uiState.title = "Reto de 30 días"
        viewModel.uiState.startDate = TestCalendar.day(0)
        viewModel.onEndDateEnabled(true)
        viewModel.uiState.endDate = TestCalendar.day(30)
        viewModel.save(onSaved: {})
        await settle()

        let saved = try! await repository.fetchActiveHabits().first
        #expect(saved?.endDate != nil)
        #expect(saved?.isActiveOn(TestCalendar.day(31), calendar: TestCalendar.fixed) == false)
        #expect(saved?.isActiveOn(TestCalendar.day(30), calendar: TestCalendar.fixed) == true)
    }

    @Test("al llegar al límite se avisa con el máximo del plan")
    func limitAlertNamesTheMax() async {
        let (viewModel, repository, suite) = Self.makeSUT(seed: HabitFixture.makeMany(3))
        defer { Self.tearDown(suite) }

        viewModel.uiState.title = "Uno más"
        viewModel.save(onSaved: {})
        await settle()

        #expect(viewModel.alert?.reason == .habitLimitReached(max: PremiumGate.freeHabitLimit))
        #expect(viewModel.alert?.message.contains("\(PremiumGate.freeHabitLimit)") == true)
        #expect(try! await repository.countActiveHabits() == 3)
    }

    @Test("editar un hábito archivado no lo desarchiva")
    func editingAnArchivedHabitKeepsItArchived() async {
        let archived = HabitFixture.make(id: "viejo", title: "Correr", isArchived: true)
        let (viewModel, repository, suite) = Self.makeSUT(habitId: "viejo", seed: [archived])
        defer { Self.tearDown(suite) }

        viewModel.onAppear()
        await settle()
        viewModel.uiState.title = "Correr más"
        viewModel.save(onSaved: {})
        await settle()

        let stillArchived = try! await repository.fetchArchivedHabits()
        #expect(stillArchived.count == 1)
        #expect(stillArchived.first?.title == "Correr más")
    }

    @Test("al editar se precarga la fecha de fin existente")
    func editingPreloadsTheEndDate() async {
        let existing = HabitFixture.make(
            id: "reto",
            startDate: TestCalendar.day(-10),
            endDate: TestCalendar.day(20)
        )
        let (viewModel, _, suite) = Self.makeSUT(habitId: "reto", seed: [existing])
        defer { Self.tearDown(suite) }

        viewModel.onAppear()
        await settle()

        #expect(viewModel.uiState.hasEndDate)
        #expect(viewModel.uiState.endDate == TestCalendar.day(20))
    }

    // MARK: - Reminder permission

    @Test("con el permiso concedido el recordatorio queda activo y sin aviso")
    func reminderStaysOnWhenGranted() async {
        let scheduler = FakeHabitReminderScheduler()
        let (viewModel, _, suite) = Self.makeSUT(reminderScheduler: scheduler)
        defer { Self.tearDown(suite) }

        viewModel.onReminderToggled(true)
        await settle()

        #expect(scheduler.requestPermissionCount == 1)
        #expect(viewModel.uiState.reminderEnabled)
        #expect(viewModel.alert == nil)
    }

    @Test("con el permiso denegado el recordatorio se apaga y avisa con enlace a Ajustes")
    func reminderTurnsOffAndExplainsWhenDenied() async {
        let scheduler = FakeHabitReminderScheduler()
        scheduler.permissionGranted = false
        let (viewModel, _, suite) = Self.makeSUT(reminderScheduler: scheduler)
        defer { Self.tearDown(suite) }

        viewModel.onReminderToggled(true)
        await settle()

        #expect(scheduler.requestPermissionCount == 1)
        #expect(viewModel.uiState.reminderEnabled == false)
        #expect(viewModel.alert?.reason == .reminderPermissionDenied)
        #expect(viewModel.alert?.offersSystemSettings == true)
        #expect(viewModel.alert?.message.isEmpty == false)
    }

    @Test("apagar el recordatorio no pide permiso ni avisa")
    func turningReminderOffNeverAsks() async {
        let scheduler = FakeHabitReminderScheduler()
        scheduler.permissionGranted = false
        let (viewModel, _, suite) = Self.makeSUT(reminderScheduler: scheduler)
        defer { Self.tearDown(suite) }
        viewModel.uiState.reminderEnabled = true

        viewModel.onReminderToggled(false)
        await settle()

        #expect(scheduler.requestPermissionCount == 0)
        #expect(viewModel.uiState.reminderEnabled == false)
        #expect(viewModel.alert == nil)
    }

    @Test("los avisos de guardado no ofrecen ir a Ajustes", arguments: [
        HabitEditorAlert.Reason.habitLimitReached(max: 3), .blankTitle, .invalidDateRange, .habitNotFound,
    ])
    func saveAlertsDontOfferSettings(reason: HabitEditorAlert.Reason) {
        #expect(HabitEditorAlert(reason: reason).offersSystemSettings == false)
    }
}
