import Foundation
import Testing
@testable import quoteAnime

/// "Mi Rutina" analytics (Android `9b82ee4`). Names and parameters must match Android's
/// `RoutineAnalytics.kt` byte for byte: both apps report into the same Firebase events.
@Suite("Analytics de Mi Rutina")
@MainActor
struct RoutineAnalyticsTests {

    private func settle() async {
        for _ in 0..<300 { await Task.yield() }
    }

    // MARK: - Names and parameters (Android's RoutineAnalytics.kt)

    @Test("los siete eventos llevan los nombres y parámetros exactos de Android")
    func eventsMatchAndroid() {
        #expect(RoutineAnalyticsEvents.tabOpened() == AnalyticsEvent(name: "routine_tab_opened", parameters: [:]))
        #expect(RoutineAnalyticsEvents.habitDetailOpened() == AnalyticsEvent(name: "habit_detail_opened", parameters: [:]))
        #expect(RoutineAnalyticsEvents.habitCreated(templateId: "theme_ninja", hasReminder: true, hasEndDate: false)
            == AnalyticsEvent(name: "habit_created", parameters: [
                "template_id": .string("theme_ninja"),
                "is_custom": .bool(false),
                "has_reminder": .bool(true),
                "has_end_date": .bool(false),
            ]))
        #expect(RoutineAnalyticsEvents.habitCompleted(habitId: "h1", isRetroactive: true, source: .app)
            == AnalyticsEvent(name: "habit_completed", parameters: [
                "habit_id": .string("h1"),
                "is_retroactive": .bool(true),
                "source": .string("app"),
            ]))
        #expect(RoutineAnalyticsEvents.habitArchived(daysActive: 12)
            == AnalyticsEvent(name: "habit_archived", parameters: ["days_active": .int(12)]))
        #expect(RoutineAnalyticsEvents.streakMilestone(days: 21)
            == AnalyticsEvent(name: "streak_milestone", parameters: ["days": .int(21)]))
        #expect(RoutineAnalyticsEvents.streakBroken(previousStreak: 4)
            == AnalyticsEvent(name: "streak_broken", parameters: ["previous_streak": .int(4)]))
    }

    @Test("un hábito sin plantilla se reporta como \"custom\"")
    func customHabitTemplateId() {
        let event = RoutineAnalyticsEvents.habitCreated(templateId: nil, hasReminder: false, hasEndDate: true)
        #expect(event.parameters["template_id"] == .string("custom"))
        #expect(event.parameters["is_custom"] == .bool(true))
        #expect(event.parameters["has_end_date"] == .bool(true))
    }

    @Test("las fuentes son \"app\" y \"notification\"")
    func sources() {
        #expect(HabitCompletionSource.app.rawValue == "app")
        #expect(HabitCompletionSource.notification.rawValue == "notification")
    }

    // MARK: - Streak thresholds

    struct StreakChange: CustomTestStringConvertible {
        let previous: Int
        let current: Int
        let expected: AnalyticsEvent?
        var testDescription: String { "\(previous) → \(current)" }
    }

    @Test("umbrales de racha en sus bordes (7, 21, 50, 100)", arguments: [
        StreakChange(previous: 6, current: 7, expected: RoutineAnalyticsEvents.streakMilestone(days: 7)),
        StreakChange(previous: 20, current: 21, expected: RoutineAnalyticsEvents.streakMilestone(days: 21)),
        StreakChange(previous: 49, current: 50, expected: RoutineAnalyticsEvents.streakMilestone(days: 50)),
        StreakChange(previous: 99, current: 100, expected: RoutineAnalyticsEvents.streakMilestone(days: 100)),
        // A jump onto a threshold (a retroactive day welding two runs) still counts.
        StreakChange(previous: 3, current: 7, expected: RoutineAnalyticsEvents.streakMilestone(days: 7)),
        StreakChange(previous: 5, current: 6, expected: nil),
        StreakChange(previous: 7, current: 8, expected: nil),
        StreakChange(previous: 100, current: 101, expected: nil),
        // Falling back onto a threshold is not a milestone (Android's test, 8 → 7).
        StreakChange(previous: 8, current: 7, expected: nil),
        StreakChange(previous: 7, current: 7, expected: nil),
        StreakChange(previous: 1, current: 0, expected: RoutineAnalyticsEvents.streakBroken(previousStreak: 1)),
        StreakChange(previous: 3, current: 0, expected: RoutineAnalyticsEvents.streakBroken(previousStreak: 3)),
        StreakChange(previous: 0, current: 0, expected: nil),
        StreakChange(previous: 0, current: 1, expected: nil),
        StreakChange(previous: 4, current: 3, expected: nil),
    ])
    func streakThresholds(change: StreakChange) {
        #expect(RoutineAnalyticsEvents.streakChange(previous: change.previous, current: change.current) == change.expected)
    }

    @Test("días activos: períodos completos de 24 h, truncados, como Android")
    func daysActive() {
        let created = TestCalendar.day(-10, hour: 9)
        #expect(RoutineAnalyticsEvents.daysActive(createdAt: created, now: TestCalendar.day(0, hour: 8)) == 9)
        #expect(RoutineAnalyticsEvents.daysActive(createdAt: created, now: TestCalendar.day(0, hour: 9)) == 10)
        #expect(RoutineAnalyticsEvents.daysActive(createdAt: created, now: created) == 0)
    }

    // MARK: - Mi Rutina list

    private func makeRoutine(
        habits: [Habit],
        completions: [String: [Date]] = [:],
        analytics: FakeRoutineAnalytics
    ) -> (RoutineViewModel, FakeHabitRepository) {
        let calendar = TestCalendar.fixed
        let repository = FakeHabitRepository(calendar: calendar)
        repository.seed(habits: habits)
        for (id, dates) in completions { repository.seedCompletions(habitId: id, dates: dates) }
        let viewModel = RoutineViewModel(
            getActiveHabitsUseCase: GetActiveHabitsUseCase(repository: repository, calendar: calendar),
            getArchivedHabitsUseCase: GetArchivedHabitsUseCase(repository: repository, calendar: calendar),
            getGlobalStreakUseCase: GetGlobalStreakUseCase(repository: repository, calendar: calendar),
            toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase(repository: repository, calendar: calendar),
            archiveHabitUseCase: ArchiveHabitUseCase(repository: repository),
            unarchiveHabitUseCase: UnarchiveHabitUseCase(repository: repository),
            deleteHabitUseCase: DeleteHabitUseCase(repository: repository),
            habitReminderScheduler: FakeHabitReminderScheduler(),
            routineWidgetRefresher: FakeRoutineWidgetRefresher(),
            premiumGate: PremiumGate.fake(),
            analytics: analytics,
            clock: { TestCalendar.today }
        )
        return (viewModel, repository)
    }

    @Test("abrir Mi Rutina se reporta una vez, aunque se vuelva del detalle")
    func tabOpenedOnce() async {
        let analytics = FakeRoutineAnalytics()
        let (viewModel, _) = makeRoutine(habits: [HabitFixture.make(id: "h")], analytics: analytics)

        viewModel.onAppear()
        await settle()
        viewModel.onAppear()
        await settle()

        #expect(analytics.names == ["routine_tab_opened"])
    }

    @Test("marcar hoy desde la lista: habit_completed no retroactivo, fuente app")
    func markTodayFromList() async {
        let analytics = FakeRoutineAnalytics()
        let (viewModel, _) = makeRoutine(habits: [HabitFixture.make(id: "h")], analytics: analytics)
        viewModel.onAppear()
        await settle()

        viewModel.onToggleToday("h")
        await settle()

        #expect(analytics.events(named: "habit_completed") == [
            RoutineAnalyticsEvents.habitCompleted(habitId: "h", isRetroactive: false, source: .app)
        ])
    }

    @Test("desmarcar no reporta habit_completed")
    func unmarkingIsNotACompletion() async {
        let analytics = FakeRoutineAnalytics()
        let (viewModel, _) = makeRoutine(
            habits: [HabitFixture.make(id: "h")],
            completions: ["h": [TestCalendar.day(0), TestCalendar.day(-1)]],
            analytics: analytics
        )
        viewModel.onAppear()
        await settle()

        viewModel.onToggleToday("h")
        await settle()

        #expect(analytics.events(named: "habit_completed").isEmpty)
    }

    @Test("llegar a 7 días seguidos dispara streak_milestone(7)")
    func reachingSevenIsAMilestone() async {
        let analytics = FakeRoutineAnalytics()
        let (viewModel, _) = makeRoutine(
            habits: [HabitFixture.make(id: "h")],
            completions: ["h": (1...6).map { TestCalendar.day(-$0) }],
            analytics: analytics
        )
        viewModel.onAppear()
        await settle()

        viewModel.onToggleToday("h")
        await settle()

        #expect(analytics.events(named: "streak_milestone") == [RoutineAnalyticsEvents.streakMilestone(days: 7)])
    }

    @Test("desmarcar hoy y bajar de 8 a 7 no es un hito")
    func fallingOntoSevenIsNotAMilestone() async {
        let analytics = FakeRoutineAnalytics()
        let (viewModel, _) = makeRoutine(
            habits: [HabitFixture.make(id: "h")],
            completions: ["h": (0...7).map { TestCalendar.day(-$0) }],
            analytics: analytics
        )
        viewModel.onAppear()
        await settle()

        viewModel.onToggleToday("h")
        await settle()

        #expect(analytics.events(named: "streak_milestone").isEmpty)
        #expect(analytics.events(named: "streak_broken").isEmpty)
    }

    @Test("desmarcar la única marca de una racha de 1 dispara streak_broken")
    func unmarkingTheOnlyDayBreaksTheStreak() async {
        let analytics = FakeRoutineAnalytics()
        let (viewModel, _) = makeRoutine(
            habits: [HabitFixture.make(id: "h")],
            completions: ["h": [TestCalendar.day(0)]],
            analytics: analytics
        )
        viewModel.onAppear()
        await settle()

        viewModel.onToggleToday("h")
        await settle()

        #expect(analytics.events(named: "streak_broken") == [RoutineAnalyticsEvents.streakBroken(previousStreak: 1)])
    }

    @Test("archivar desde la lista reporta los días activos")
    func archiveFromList() async {
        let analytics = FakeRoutineAnalytics()
        // Ten days and one hour before the view model's clock (`TestCalendar.today`, noon).
        let createdAt = TestCalendar.day(-10, hour: 11)
        let (viewModel, _) = makeRoutine(
            habits: [HabitFixture.make(id: "h", createdAt: createdAt)],
            analytics: analytics
        )
        viewModel.onAppear()
        await settle()

        viewModel.onArchive("h")
        await settle()

        #expect(analytics.events(named: "habit_archived") == [RoutineAnalyticsEvents.habitArchived(daysActive: 10)])
    }

    @Test("restaurar no reporta nada")
    func unarchiveIsSilent() async {
        let analytics = FakeRoutineAnalytics()
        let (viewModel, repository) = makeRoutine(habits: [HabitFixture.make(id: "h", isArchived: true)], analytics: analytics)
        viewModel.onFilterChanged(.archived)
        await settle()

        viewModel.onUnarchive("h")
        await settle()

        #expect(analytics.events.isEmpty)
        #expect(repository.archivedIds.isEmpty)
    }

    // MARK: - Habit detail

    private func makeDetail(
        habit: Habit = HabitFixture.make(id: "h"),
        completions: [Date] = [],
        analytics: FakeRoutineAnalytics
    ) -> HabitDetailViewModel {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: [habit])
        repository.seedCompletions(habitId: habit.id, dates: completions)
        return HabitDetailViewModel(
            habitId: habit.id,
            repository: repository,
            toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase(repository: repository, calendar: TestCalendar.fixed),
            archiveHabitUseCase: ArchiveHabitUseCase(repository: repository),
            unarchiveHabitUseCase: UnarchiveHabitUseCase(repository: repository),
            deleteHabitUseCase: DeleteHabitUseCase(repository: repository),
            habitReminderScheduler: FakeHabitReminderScheduler(),
            routineWidgetRefresher: FakeRoutineWidgetRefresher(),
            today: TestCalendar.today,
            calendar: TestCalendar.fixed,
            analytics: analytics
        )
    }

    @Test("abrir el detalle se reporta una vez por visita")
    func detailOpenedOnce() async {
        let analytics = FakeRoutineAnalytics()
        let viewModel = makeDetail(analytics: analytics)

        viewModel.onAppear()
        viewModel.onAppear()
        await settle()

        #expect(analytics.names == ["habit_detail_opened"])
    }

    @Test("marcar un día pasado en el calendario lleva isRetroactive = true", arguments: [-1, -5, -20])
    func pastDayIsRetroactive(offset: Int) async {
        let analytics = FakeRoutineAnalytics()
        let viewModel = makeDetail(analytics: analytics)
        viewModel.onAppear()
        await settle()

        viewModel.onDayTap(TestCalendar.day(offset, hour: 8))
        await settle()

        #expect(analytics.events(named: "habit_completed") == [
            RoutineAnalyticsEvents.habitCompleted(habitId: "h", isRetroactive: true, source: .app)
        ])
    }

    @Test("marcar hoy en el calendario, a cualquier hora, no es retroactivo", arguments: [0, 8, 23])
    func todayIsNotRetroactive(hour: Int) async {
        let analytics = FakeRoutineAnalytics()
        let viewModel = makeDetail(analytics: analytics)

        viewModel.onDayTap(TestCalendar.day(0, hour: hour))
        await settle()

        #expect(analytics.events(named: "habit_completed") == [
            RoutineAnalyticsEvents.habitCompleted(habitId: "h", isRetroactive: false, source: .app)
        ])
    }

    @Test("desmarcar en el calendario no reporta nada, ni rachas: Android sólo las mide en la lista")
    func detailUnmarkIsSilent() async {
        let analytics = FakeRoutineAnalytics()
        let viewModel = makeDetail(completions: [TestCalendar.day(-2)], analytics: analytics)

        viewModel.onDayTap(TestCalendar.day(-2))
        await settle()

        #expect(analytics.events.isEmpty)
    }

    @Test("DIVERGENCIA: completar el 7º día desde el calendario no dispara streak_milestone, igual que Android")
    func detailNeverTracksStreaks() async {
        let analytics = FakeRoutineAnalytics()
        let viewModel = makeDetail(completions: (0...5).map { TestCalendar.day(-$0) }, analytics: analytics)

        viewModel.onDayTap(TestCalendar.day(-6))
        await settle()

        #expect(analytics.events(named: "streak_milestone").isEmpty)
    }

    @Test("archivar desde el detalle reporta los días activos")
    func archiveFromDetail() async {
        let analytics = FakeRoutineAnalytics()
        let viewModel = makeDetail(
            habit: HabitFixture.make(id: "h", createdAt: TestCalendar.day(-30, hour: 12)),
            analytics: analytics
        )
        viewModel.onAppear()
        await settle()

        viewModel.onArchive()
        await settle()

        #expect(analytics.events(named: "habit_archived") == [RoutineAnalyticsEvents.habitArchived(daysActive: 30)])
    }

    // MARK: - Editor

    private func makeEditor(
        habitId: String? = nil,
        seed: [Habit] = [],
        premium: Bool = false,
        analytics: FakeRoutineAnalytics
    ) -> HabitEditorViewModel {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: seed)
        return HabitEditorViewModel(
            habitId: habitId,
            createHabitUseCase: CreateHabitUseCase(
                repository: repository, premiumGate: PremiumGate.fake(premium: premium), calendar: TestCalendar.fixed
            ),
            updateHabitUseCase: UpdateHabitUseCase(repository: repository, calendar: TestCalendar.fixed),
            habitRepository: repository,
            habitReminderScheduler: FakeHabitReminderScheduler(),
            routineWidgetRefresher: FakeRoutineWidgetRefresher(),
            analytics: analytics
        )
    }

    @Test("crear un hábito propio: template_id custom y lo que se configuró")
    func createCustomHabit() async {
        let analytics = FakeRoutineAnalytics()
        let viewModel = makeEditor(analytics: analytics)
        viewModel.uiState.title = "Leer"
        viewModel.uiState.reminderEnabled = true
        viewModel.onEndDateEnabled(true)

        viewModel.save {}
        await settle()

        #expect(analytics.events == [
            RoutineAnalyticsEvents.habitCreated(templateId: nil, hasReminder: true, hasEndDate: true)
        ])
    }

    @Test("crear desde una plantilla reporta su id")
    func createFromTemplate() async throws {
        let analytics = FakeRoutineAnalytics()
        let viewModel = makeEditor(analytics: analytics)
        let template = try #require(DefaultHabitTemplates.all.first)

        viewModel.onTemplateSelected(template)
        viewModel.save {}
        await settle()

        #expect(analytics.events == [
            RoutineAnalyticsEvents.habitCreated(templateId: template.id, hasReminder: false, hasEndDate: false)
        ])
    }

    @Test("editar un hábito existente no es una creación")
    func editingIsNotACreation() async {
        let analytics = FakeRoutineAnalytics()
        let habit = HabitFixture.make(id: "h", title: "Leer")
        let viewModel = makeEditor(habitId: "h", seed: [habit], analytics: analytics)
        viewModel.onAppear()
        await settle()

        viewModel.uiState.title = "Leer más"
        viewModel.save {}
        await settle()

        #expect(analytics.events.isEmpty)
    }

    @Test("una creación rechazada por el límite gratuito no se reporta")
    func refusedCreationIsSilent() async {
        let analytics = FakeRoutineAnalytics()
        let viewModel = makeEditor(seed: HabitFixture.makeMany(PremiumGate.freeHabitLimit), analytics: analytics)
        viewModel.uiState.title = "Uno más"

        viewModel.save {}
        await settle()

        #expect(analytics.events.isEmpty)
        #expect(viewModel.alert != nil)
    }

    // MARK: - Onboarding

    @Test("el hábito del onboarding se reporta con su plantilla y sin recordatorio ni fin")
    func onboardingCreation() async throws {
        let analytics = FakeRoutineAnalytics()
        let viewModel = OnboardingViewModel()
        let template = try #require(viewModel.habitTemplates.first)

        await confirmation("onComplete se llama") { completed in
            viewModel.setup(
                setOnboardingCompleted: SetOnboardingCompletedUseCase(repository: FakeUserPreferencesRepository()),
                createHabitUseCase: CreateHabitUseCase(repository: FakeHabitRepository(), premiumGate: PremiumGate.fake()),
                analytics: analytics,
                onComplete: { completed() }
            )
            viewModel.selectTemplate(template.id)
            viewModel.complete()
            await Task.yield()
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        #expect(analytics.events == [
            RoutineAnalyticsEvents.habitCreated(templateId: template.id, hasReminder: false, hasEndDate: false)
        ])
    }

    // MARK: - "Hecho" from the notification

    private func makeDoneAction(
        habit: Habit? = HabitFixture.make(id: "h"),
        completions: [Date] = [],
        analytics: FakeRoutineAnalytics
    ) -> (HabitReminderDoneAction, FakeHabitRepository) {
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        if let habit { repository.seed(habits: [habit]) }
        repository.seedCompletions(habitId: "h", dates: completions)
        let action = HabitReminderDoneAction(
            repository: repository,
            toggleHabitCompletion: ToggleHabitCompletionUseCase(repository: repository, calendar: TestCalendar.fixed),
            analytics: analytics,
            calendar: TestCalendar.fixed
        )
        return (action, repository)
    }

    @Test("\"Hecho\" en la notificación marca hoy y reporta fuente notification, no retroactivo")
    func notificationDoneMarksAndTracks() async throws {
        let analytics = FakeRoutineAnalytics()
        let (action, repository) = makeDoneAction(analytics: analytics)

        let marked = await action.execute(habitId: "h", today: TestCalendar.day(0, hour: 21))

        #expect(marked)
        #expect(try await repository.isCompleted(habitId: "h", date: TestCalendar.today))
        #expect(analytics.events == [
            RoutineAnalyticsEvents.habitCompleted(habitId: "h", isRetroactive: false, source: .notification)
        ])
    }

    @Test("\"Hecho\" sobre un día ya marcado lo deja marcado y no reporta nada")
    func notificationDoneIsIdempotent() async throws {
        let analytics = FakeRoutineAnalytics()
        let (action, repository) = makeDoneAction(completions: [TestCalendar.today], analytics: analytics)

        let marked = await action.execute(habitId: "h", today: TestCalendar.today)

        #expect(!marked)
        #expect(try await repository.isCompleted(habitId: "h", date: TestCalendar.today))
        #expect(analytics.events.isEmpty)
    }

    @Test("\"Hecho\" de un hábito borrado o ya terminado no hace nada")
    func notificationDoneForInactiveHabit() async throws {
        let analytics = FakeRoutineAnalytics()
        let ended = HabitFixture.make(id: "h", endDate: TestCalendar.day(-1))
        let (endedAction, endedRepository) = makeDoneAction(habit: ended, analytics: analytics)
        let (deletedAction, _) = makeDoneAction(habit: nil, analytics: analytics)

        #expect(await endedAction.execute(habitId: "h", today: TestCalendar.today) == false)
        #expect(await deletedAction.execute(habitId: "h", today: TestCalendar.today) == false)
        #expect(try await endedRepository.isCompleted(habitId: "h", date: TestCalendar.today) == false)
        #expect(analytics.events.isEmpty)
    }
}
