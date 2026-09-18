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
        reminderScheduler: FakeHabitReminderScheduler = FakeHabitReminderScheduler(),
        widgetRefresher: FakeRoutineWidgetRefresher = FakeRoutineWidgetRefresher(),
        templates: GetHabitTemplatesUseCase = GetHabitTemplatesUseCase()
    ) -> (HabitEditorViewModel, FakeHabitRepository) {
        let gate = PremiumGate.fake()
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: seed)
        let viewModel = HabitEditorViewModel(
            habitId: habitId,
            createHabitUseCase: CreateHabitUseCase(
                repository: repository, premiumGate: gate, calendar: TestCalendar.fixed
            ),
            updateHabitUseCase: UpdateHabitUseCase(repository: repository, calendar: TestCalendar.fixed),
            habitRepository: repository,
            habitReminderScheduler: reminderScheduler,
            routineWidgetRefresher: widgetRefresher,
            getHabitTemplates: templates
        )
        return (viewModel, repository)
    }


    private func settle() async {
        for _ in 0..<200 { await Task.yield() }
    }

    // MARK: - End date opt-in

    @Test("por defecto no hay fecha de fin")
    func endDateIsOptOutByDefault() {
        let (viewModel, _) = Self.makeSUT()
        #expect(viewModel.uiState.hasEndDate == false)
    }

    @Test("al activar la fecha de fin nunca queda antes de la de inicio")
    func enablingEndDateClampsIt() {
        let (viewModel, _) = Self.makeSUT()
        viewModel.uiState.startDate = TestCalendar.day(0)
        viewModel.uiState.endDate = TestCalendar.day(-10)

        viewModel.onEndDateEnabled(true)

        #expect(viewModel.uiState.endDate >= viewModel.uiState.startDate)
    }

    @Test("mover la fecha de inicio más allá del fin arrastra el fin", arguments: [1, 5, 40])
    func movingStartPastEndDragsEnd(offset: Int) {
        let (viewModel, _) = Self.makeSUT()
        viewModel.uiState.startDate = TestCalendar.day(0)
        viewModel.onEndDateEnabled(true)
        viewModel.uiState.endDate = TestCalendar.day(0)

        viewModel.onStartDateChanged(TestCalendar.day(offset))

        #expect(viewModel.uiState.endDate == TestCalendar.day(offset))
    }

    @Test("mover la fecha de inicio hacia atrás no toca el fin")
    func movingStartBackLeavesEndAlone() {
        let (viewModel, _) = Self.makeSUT()
        viewModel.uiState.startDate = TestCalendar.day(0)
        viewModel.onEndDateEnabled(true)
        viewModel.uiState.endDate = TestCalendar.day(10)

        viewModel.onStartDateChanged(TestCalendar.day(-5))

        #expect(viewModel.uiState.endDate == TestCalendar.day(10))
    }

    @Test("sin fecha de fin activada, mover el inicio no toca nada más")
    func movingStartWithoutEndDateIsInert() {
        let (viewModel, _) = Self.makeSUT()
        viewModel.uiState.endDate = TestCalendar.day(-100)

        viewModel.onStartDateChanged(TestCalendar.day(0))

        #expect(viewModel.uiState.endDate == TestCalendar.day(-100), "el valor guardado del picker apagado no se usa")
    }

    // MARK: - Saving

    @Test("guardar sin fecha de fin deja el hábito indefinido")
    func savingWithoutEndDateLeavesItNil() async {
        let (viewModel, repository) = Self.makeSUT()
        viewModel.uiState.title = "Meditar"
        viewModel.save(onSaved: {})
        await settle()

        let saved = try! await repository.fetchActiveHabits().first
        #expect(saved?.endDate == nil)
    }

    @Test("guardar con fecha de fin la persiste")
    func savingWithEndDatePersistsIt() async {
        let (viewModel, repository) = Self.makeSUT()
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
        let (viewModel, repository) = Self.makeSUT(seed: HabitFixture.makeMany(3))
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
        let (viewModel, repository) = Self.makeSUT(habitId: "viejo", seed: [archived])
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
        let (viewModel, _) = Self.makeSUT(habitId: "reto", seed: [existing])
        viewModel.onAppear()
        await settle()

        #expect(viewModel.uiState.hasEndDate)
        #expect(viewModel.uiState.endDate == TestCalendar.day(20))
    }

    // MARK: - Reminder permission

    @Test("con el permiso concedido el recordatorio queda activo y sin aviso")
    func reminderStaysOnWhenGranted() async {
        let scheduler = FakeHabitReminderScheduler()
        let (viewModel, _) = Self.makeSUT(reminderScheduler: scheduler)
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
        let (viewModel, _) = Self.makeSUT(reminderScheduler: scheduler)
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
        let (viewModel, _) = Self.makeSUT(reminderScheduler: scheduler)
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

    // MARK: - Home-screen widgets

    @Test("guardar un hábito pide refrescar los widgets")
    func savingRefreshesTheWidgets() async {
        let refresher = FakeRoutineWidgetRefresher()
        let (viewModel, _) = Self.makeSUT(widgetRefresher: refresher)
        viewModel.uiState.title = "Meditar"

        viewModel.save(onSaved: {})
        await settle()

        #expect(refresher.refreshCount == 1)
    }

    @Test("un guardado rechazado no refresca los widgets")
    func rejectedSaveDoesNotRefresh() async {
        let refresher = FakeRoutineWidgetRefresher()
        let (viewModel, _) = Self.makeSUT(
            seed: HabitFixture.makeMany(PremiumGate.freeHabitLimit),
            widgetRefresher: refresher
        )
        viewModel.uiState.title = "Uno más"

        viewModel.save(onSaved: {})
        await settle()

        #expect(viewModel.alert?.reason == .habitLimitReached(max: PremiumGate.freeHabitLimit))
        #expect(refresher.refreshCount == 0)
    }

    // MARK: - Remote templates (492f80f)

    private static let remoteTemplates = [
        HabitTemplateDTO(id: "remote_read", title: "template_read", iconKey: "book", order: 1, themeColorIndex: 2),
        HabitTemplateDTO(id: "remote_walk", title: "Caminar al sol", iconKey: "directions_walk", order: 2),
    ]

    @Test("las sugerencias locales están al instante, antes de la red")
    func bundledTemplatesAreImmediate() {
        let remote = FakeHabitTemplateRemoteSource(Self.remoteTemplates)
        let (viewModel, _) = Self.makeSUT(templates: GetHabitTemplatesUseCase(remote: remote))

        #expect(viewModel.templates == DefaultHabitTemplates.all)
        #expect(remote.fetchCount == 0)
    }

    @Test("las remotas reemplazan a las locales cuando llegan")
    func remoteReplacesBundled() async {
        let remote = FakeHabitTemplateRemoteSource(Self.remoteTemplates)
        let (viewModel, _) = Self.makeSUT(templates: GetHabitTemplatesUseCase(remote: remote))

        await viewModel.loadTemplates(isPremium: { false })

        #expect(viewModel.templates.map(\.id) == ["remote_read", "remote_walk"])
    }

    @Test("una sugerencia ya aplicada no se cambia cuando llegan las remotas")
    func appliedSuggestionIsKept() async {
        let remote = FakeHabitTemplateRemoteSource(Self.remoteTemplates)
        let (viewModel, _) = Self.makeSUT(templates: GetHabitTemplatesUseCase(remote: remote))
        viewModel.applyDefaultTemplate(from: viewModel.templates, isPremium: false)
        let applied = viewModel.uiState.title

        await viewModel.loadTemplates(isPremium: { false })

        #expect(viewModel.uiState.templateId == "theme_ninja")
        #expect(viewModel.uiState.title == applied)
    }

    @Test("sin sugerencia aplicada, se aplica la primera remota")
    func firstRemoteAppliedWhenNoneYet() async {
        let remote = FakeHabitTemplateRemoteSource(Self.remoteTemplates)
        let (viewModel, _) = Self.makeSUT(templates: GetHabitTemplatesUseCase(remote: remote))

        await viewModel.loadTemplates(isPremium: { false })

        #expect(viewModel.uiState.templateId == "remote_read")
        #expect(viewModel.uiState.title == String(localized: "Leer"))
        #expect(viewModel.uiState.colorIndex == 2)
        #expect(viewModel.uiState.themeKey == nil)
    }

    @Test("sin red el editor se queda con las locales")
    func offlineKeepsBundled() async {
        let remote = FakeHabitTemplateRemoteSource(error: FakeHabitTemplateRemoteSource.Offline())
        let (viewModel, _) = Self.makeSUT(templates: GetHabitTemplatesUseCase(remote: remote))

        await viewModel.loadTemplates(isPremium: { false })

        #expect(viewModel.templates == DefaultHabitTemplates.all)
        #expect(viewModel.uiState.templateId == "theme_ninja")
    }

    @Test("editando un hábito no se piden plantillas a la red")
    func editingSkipsFetch() async {
        let remote = FakeHabitTemplateRemoteSource(Self.remoteTemplates)
        let (viewModel, _) = Self.makeSUT(habitId: "h1", templates: GetHabitTemplatesUseCase(remote: remote))

        await viewModel.loadTemplates(isPremium: { false })

        #expect(remote.fetchCount == 0)
        #expect(viewModel.uiState.templateId == nil)
    }

    // MARK: - Reminder weekdays

    @Test("encender el recordatorio sin días elige los siete")
    func enablingReminderWithNoWeekdaysPicksAll() async {
        let (viewModel, _) = Self.makeSUT()
        #expect(viewModel.uiState.reminderWeekdays.isEmpty)

        viewModel.onReminderToggled(true)

        #expect(viewModel.uiState.reminderWeekdays == Set(1...7))
        #expect(viewModel.uiState.reminderHasNoWeekdays == false)
    }

    @Test("encender el recordatorio conserva los días ya elegidos")
    func enablingReminderKeepsPickedWeekdays() async {
        let (viewModel, _) = Self.makeSUT()
        viewModel.onWeekdayToggled(2)
        viewModel.onWeekdayToggled(4)

        viewModel.onReminderToggled(true)

        #expect(viewModel.uiState.reminderWeekdays == [2, 4])
    }

    @Test("quitar el último día avisa en el editor")
    func removingLastWeekdayWarns() async {
        let (viewModel, _) = Self.makeSUT()
        viewModel.onReminderToggled(true)
        for weekday in 1...7 { viewModel.onWeekdayToggled(weekday) }

        #expect(viewModel.uiState.reminderEnabled == true)
        #expect(viewModel.uiState.reminderHasNoWeekdays == true)
    }

    @Test("guardar con el recordatorio encendido y sin días lo guarda apagado")
    func savingReminderWithNoWeekdaysStoresItOff() async {
        let scheduler = FakeHabitReminderScheduler()
        let (viewModel, repository) = Self.makeSUT(reminderScheduler: scheduler)
        viewModel.uiState.title = "Leer"
        viewModel.onReminderToggled(true)
        await settle()
        for weekday in 1...7 { viewModel.onWeekdayToggled(weekday) }

        var didSave = false
        viewModel.save(onSaved: { didSave = true })
        await settle()

        let saved = try! await repository.fetchActiveHabits().first
        #expect(didSave)
        #expect(saved?.reminderEnabled == false)
        #expect(saved?.reminderWeekdays.isEmpty == true)
    }

    @Test("un hábito viejo con recordatorio encendido y sin días se abre apagado")
    func legacyReminderWithoutWeekdaysOpensOff() async {
        let legacy = HabitFixture.make(id: "viejo", title: "Correr", reminderEnabled: true, reminderWeekdays: [])
        let (viewModel, _) = Self.makeSUT(habitId: "viejo", seed: [legacy])

        viewModel.onAppear()
        await settle()

        #expect(viewModel.uiState.title == "Correr")
        #expect(viewModel.uiState.reminderEnabled == false)
    }

    @Test("un hábito con recordatorio y días se abre encendido")
    func reminderWithWeekdaysOpensOn() async {
        let habit = HabitFixture.make(id: "h", title: "Correr", reminderEnabled: true, reminderWeekdays: [2, 6])
        let (viewModel, _) = Self.makeSUT(habitId: "h", seed: [habit])

        viewModel.onAppear()
        await settle()

        #expect(viewModel.uiState.reminderEnabled == true)
        #expect(viewModel.uiState.reminderWeekdays == [2, 6])
    }
}
