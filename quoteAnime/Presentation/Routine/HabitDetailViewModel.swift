import SwiftUI
import Combine

struct HabitDetailUiState {
    var habit: Habit?
    var completions: Set<Date> = []
    var streak: StreakState = StreakState()
    /// Any day inside the month being shown; the grid normalises it.
    var visibleMonth: Date = Date()
    /// Last day tapped — echoed back in the callout under the heatmap.
    var selectedDate: Date?
    var isLoading: Bool = true
    /// Set once archiving or deleting completes, so the screen can pop itself.
    var shouldDismiss: Bool = false
}

/// Mirrors Android's `HabitDetailViewModel`, including what happens after each action:
/// archiving and deleting close the screen (the habit leaves the list you came from), while
/// restoring keeps it open and just flips the menu back to "Archivar".
@MainActor
final class HabitDetailViewModel: ObservableObject {
    @Published var uiState = HabitDetailUiState()

    private let habitId: String
    private let repository: HabitRepository
    private let toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase
    private let archiveHabitUseCase: ArchiveHabitUseCase
    private let unarchiveHabitUseCase: UnarchiveHabitUseCase
    private let deleteHabitUseCase: DeleteHabitUseCase
    private let habitReminderScheduler: HabitReminderScheduler
    private let calculateStreak: CalculateStreakUseCase
    private let calendar: Calendar
    /// Injected so the screen can be tested at a fixed date, the same reason Android's view
    /// model takes a `Clock`.
    private let today: Date

    init(
        habitId: String,
        repository: HabitRepository,
        toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase,
        archiveHabitUseCase: ArchiveHabitUseCase,
        unarchiveHabitUseCase: UnarchiveHabitUseCase,
        deleteHabitUseCase: DeleteHabitUseCase,
        habitReminderScheduler: HabitReminderScheduler,
        today: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.habitId = habitId
        self.repository = repository
        self.toggleHabitCompletionUseCase = toggleHabitCompletionUseCase
        self.archiveHabitUseCase = archiveHabitUseCase
        self.unarchiveHabitUseCase = unarchiveHabitUseCase
        self.deleteHabitUseCase = deleteHabitUseCase
        self.habitReminderScheduler = habitReminderScheduler
        self.calculateStreak = CalculateStreakUseCase(calendar: calendar)
        self.calendar = calendar
        self.today = today
        self.uiState.visibleMonth = today
    }

    var currentCalendar: Calendar { calendar }
    var currentToday: Date { today }

    func onAppear() {
        Task { await load() }
    }

    /// The calendar already refuses to tap an unmarkable day, so a rejection here means the
    /// habit changed underneath us (deleted elsewhere, its end date moved). Nothing to report
    /// to the user — reloading puts the screen back in sync.
    func onDayTap(_ date: Date) {
        Task {
            do {
                try await toggleHabitCompletionUseCase.execute(habitId: habitId, date: date, today: today)
                uiState.selectedDate = calendar.startOfDay(for: date)
            } catch {
                print("[HabitDetailViewModel] toggle rechazado: \(error)")
            }
            await load()
        }
    }

    func onMonthChanged(by months: Int) {
        uiState.visibleMonth = CalendarMonthGrid.month(uiState.visibleMonth, offsetBy: months, calendar: calendar)
    }

    func onArchive() {
        Task {
            do {
                try await archiveHabitUseCase.execute(id: habitId)
                await habitReminderScheduler.cancel(habitId: habitId)
                uiState.shouldDismiss = true
            } catch {
                print("[HabitDetailViewModel] archive error: \(error)")
            }
        }
    }

    func onUnarchive() {
        Task {
            do {
                try await unarchiveHabitUseCase.execute(id: habitId)
                if let restored = try await repository.fetchHabit(id: habitId) {
                    await habitReminderScheduler.schedule(habit: restored)
                }
                await load()
            } catch {
                print("[HabitDetailViewModel] unarchive error: \(error)")
            }
        }
    }

    /// Permanent, unlike archiving — the screen must confirm before calling this.
    func onDelete() {
        Task {
            do {
                try await deleteHabitUseCase.execute(id: habitId)
                await habitReminderScheduler.cancel(habitId: habitId)
                uiState.shouldDismiss = true
            } catch {
                print("[HabitDetailViewModel] delete error: \(error)")
            }
        }
    }

    private func load() async {
        do {
            let habit = try await repository.fetchHabit(id: habitId)
            let dates = try await repository.fetchCompletions(habitId: habitId)
            uiState.habit = habit
            uiState.completions = Set(dates.map { calendar.startOfDay(for: $0) })
            uiState.streak = calculateStreak.execute(dates: dates, today: today)
        } catch {
            print("[HabitDetailViewModel] load error: \(error)")
        }
        uiState.isLoading = false
    }
}
