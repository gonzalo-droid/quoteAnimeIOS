import Foundation
import Testing
@testable import quoteAnime

/// The detail screen is where retroactive marking happens, so this is where the interesting
/// case lives: marking a past day that welds two separate runs into one streak.
@Suite("HabitDetailViewModel")
@MainActor
struct HabitDetailViewModelTests {

    private func makeSUT(
        habit: Habit? = nil,
        completions: [Date] = []
    ) -> (HabitDetailViewModel, FakeHabitRepository) {
        let habit = habit ?? HabitFixture.make(id: "meditar")
        let repository = FakeHabitRepository(calendar: TestCalendar.fixed)
        repository.seed(habits: [habit])
        if !completions.isEmpty {
            repository.seedCompletions(habitId: habit.id, dates: completions)
        }
        let viewModel = HabitDetailViewModel(
            habitId: habit.id,
            repository: repository,
            toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase(
                repository: repository, calendar: TestCalendar.fixed
            ),
            archiveHabitUseCase: ArchiveHabitUseCase(repository: repository),
            unarchiveHabitUseCase: UnarchiveHabitUseCase(repository: repository),
            deleteHabitUseCase: DeleteHabitUseCase(repository: repository),
            habitReminderScheduler: FakeHabitReminderScheduler(),
            today: TestCalendar.today,
            calendar: TestCalendar.fixed
        )
        return (viewModel, repository)
    }

    /// Every action spawns a detached `Task`; this yields until the view model settles instead
    /// of guessing a sleep duration.
    private func settle() async {
        for _ in 0..<200 {
            await Task.yield()
        }
    }

    // MARK: - Loading

    @Test("al abrirse carga el hábito, sus completions y la racha")
    func loadsOnAppear() async {
        let (viewModel, _) = makeSUT(
            completions: [TestCalendar.day(0), TestCalendar.day(-1), TestCalendar.day(-2)]
        )

        viewModel.onAppear()
        await settle()

        #expect(viewModel.uiState.isLoading == false)
        #expect(viewModel.uiState.habit?.id == "meditar")
        #expect(viewModel.uiState.completions.count == 3)
        #expect(viewModel.uiState.streak.current == 3)
        #expect(viewModel.uiState.streak.completedToday)
    }

    @Test("el mes visible arranca en el mes de hoy")
    func visibleMonthStartsOnToday() {
        let (viewModel, _) = makeSUT()

        #expect(TestCalendar.fixed.isDate(
            viewModel.uiState.visibleMonth, equalTo: TestCalendar.today, toGranularity: .month
        ))
    }

    // MARK: - Retroactive marking

    @Test("marcar un día pasado dentro del rango lo completa", arguments: [-1, -3, -7, -29])
    func marksPastDaysInsideTheRange(offset: Int) async {
        let (viewModel, repository) = makeSUT()
        viewModel.onAppear()
        await settle()

        viewModel.onDayTap(TestCalendar.day(offset))
        await settle()

        #expect(repository.completionCount(habitId: "meditar") == 1)
        #expect(viewModel.uiState.completions.contains(TestCalendar.fixed.startOfDay(for: TestCalendar.day(offset))))
        #expect(viewModel.uiState.selectedDate == TestCalendar.fixed.startOfDay(for: TestCalendar.day(offset)))
    }

    @Test("volver a tocar un día marcado lo desmarca")
    func tappingAgainUnmarks() async {
        let (viewModel, repository) = makeSUT(completions: [TestCalendar.day(-3)])
        viewModel.onAppear()
        await settle()

        viewModel.onDayTap(TestCalendar.day(-3))
        await settle()

        #expect(repository.completionCount(habitId: "meditar") == 0)
        #expect(viewModel.uiState.completions.isEmpty)
    }

    @Test("marcar un día pasado que une dos rachas separadas las funde en una sola")
    func markingAPastDayWeldsTwoStreaks() async {
        // Runs: {-1, -2} and {-4, -5}. Day -3 is the gap between them.
        let (viewModel, _) = makeSUT(
            completions: [
                TestCalendar.day(-1), TestCalendar.day(-2),
                TestCalendar.day(-4), TestCalendar.day(-5)
            ]
        )
        viewModel.onAppear()
        await settle()

        #expect(viewModel.uiState.streak.current == 2, "antes de unir: sólo la racha viva de 2")
        #expect(viewModel.uiState.streak.best == 2)

        viewModel.onDayTap(TestCalendar.day(-3))
        await settle()

        #expect(viewModel.uiState.streak.current == 5, "los dos tramos más el día del medio")
        #expect(viewModel.uiState.streak.best == 5)
        #expect(viewModel.uiState.streak.completedToday == false, "hoy sigue sin marcar")
        #expect(viewModel.uiState.completions.count == 5)
    }

    @Test("desmarcar el día del medio vuelve a partir la racha")
    func unmarkingTheMiddleDaySplitsItAgain() async {
        let (viewModel, _) = makeSUT(
            completions: [
                TestCalendar.day(-1), TestCalendar.day(-2), TestCalendar.day(-3),
                TestCalendar.day(-4), TestCalendar.day(-5)
            ]
        )
        viewModel.onAppear()
        await settle()
        #expect(viewModel.uiState.streak.current == 5)

        viewModel.onDayTap(TestCalendar.day(-3))
        await settle()

        #expect(viewModel.uiState.streak.current == 2)
        #expect(viewModel.uiState.streak.best == 2)
    }

    // MARK: - Rejections

    @Test("un día futuro no se marca", arguments: [1, 5, 30])
    func futureDaysAreNotMarked(offset: Int) async {
        let (viewModel, repository) = makeSUT()
        viewModel.onAppear()
        await settle()

        viewModel.onDayTap(TestCalendar.day(offset))
        await settle()

        #expect(repository.completionCount(habitId: "meditar") == 0)
        #expect(viewModel.uiState.selectedDate == nil, "un rechazo no mueve el día seleccionado")
    }

    @Test("un día anterior al inicio del hábito no se marca")
    func daysBeforeStartAreNotMarked() async {
        let (viewModel, repository) = makeSUT()
        viewModel.onAppear()
        await settle()

        viewModel.onDayTap(TestCalendar.day(-31))
        await settle()

        #expect(repository.completionCount(habitId: "meditar") == 0)
        #expect(viewModel.uiState.selectedDate == nil)
    }

    @Test("un día posterior a la fecha de fin no se marca")
    func daysAfterEndAreNotMarked() async {
        let habit = HabitFixture.make(
            id: "meditar",
            startDate: TestCalendar.day(-30),
            endDate: TestCalendar.day(-10)
        )
        let (viewModel, repository) = makeSUT(habit: habit)
        viewModel.onAppear()
        await settle()

        viewModel.onDayTap(TestCalendar.day(-5))
        await settle()

        #expect(repository.completionCount(habitId: "meditar") == 0)
    }

    // MARK: - Month navigation

    @Test("navegar meses mueve el mes visible", arguments: [-12, -2, -1, 1, 3])
    func monthNavigationMovesTheVisibleMonth(delta: Int) {
        let (viewModel, _) = makeSUT()

        viewModel.onMonthChanged(by: delta)

        let expected = TestCalendar.fixed.date(byAdding: .month, value: delta, to: TestCalendar.today)!
        #expect(TestCalendar.fixed.isDate(
            viewModel.uiState.visibleMonth, equalTo: expected, toGranularity: .month
        ))
    }

    @Test("ir y volver deja el mes como estaba")
    func monthNavigationRoundTrips() {
        let (viewModel, _) = makeSUT()

        viewModel.onMonthChanged(by: -1)
        viewModel.onMonthChanged(by: 1)

        #expect(TestCalendar.fixed.isDate(
            viewModel.uiState.visibleMonth, equalTo: TestCalendar.today, toGranularity: .month
        ))
    }

    // MARK: - Archive / restore / delete

    @Test("archivar cierra la pantalla y deja el hábito archivado")
    func archivingDismissesTheScreen() async {
        let (viewModel, repository) = makeSUT()
        viewModel.onAppear()
        await settle()

        viewModel.onArchive()
        await settle()

        let archived = try! await repository.fetchArchivedHabits()
        let activeCount = try! await repository.countActiveHabits()
        #expect(viewModel.uiState.shouldDismiss)
        #expect(archived.count == 1)
        #expect(activeCount == 0)
    }

    @Test("restaurar deja la pantalla abierta con el hábito activo")
    func unarchivingKeepsTheScreenOpen() async {
        let (viewModel, repository) = makeSUT(habit: HabitFixture.make(id: "meditar", isArchived: true))
        viewModel.onAppear()
        await settle()
        #expect(viewModel.uiState.habit?.isArchived == true)

        viewModel.onUnarchive()
        await settle()

        let activeCount = try! await repository.countActiveHabits()
        #expect(viewModel.uiState.shouldDismiss == false, "restaurar no cierra el detalle")
        #expect(viewModel.uiState.habit?.isArchived == false)
        #expect(activeCount == 1)
    }

    @Test("borrar cierra la pantalla y se lleva el historial")
    func deletingDismissesAndClearsHistory() async {
        let (viewModel, repository) = makeSUT(
            completions: [TestCalendar.day(0), TestCalendar.day(-1)]
        )
        viewModel.onAppear()
        await settle()

        viewModel.onDelete()
        await settle()

        #expect(viewModel.uiState.shouldDismiss)
        #expect(repository.habits.isEmpty)
        #expect(repository.completionCount(habitId: "meditar") == 0)
    }

    @Test("archivar conserva el historial de completions")
    func archivingKeepsHistory() async {
        let (viewModel, repository) = makeSUT(
            completions: [TestCalendar.day(0), TestCalendar.day(-1), TestCalendar.day(-2)]
        )
        viewModel.onAppear()
        await settle()

        viewModel.onArchive()
        await settle()

        #expect(repository.completionCount(habitId: "meditar") == 3)
    }
}
