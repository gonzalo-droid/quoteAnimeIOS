import SwiftUI

/// Habit detail: six months of history, a navigable month calendar that marks past days, and
/// the archive / restore / delete actions.
///
/// Android shows this as a fullscreen `ModalBottomSheet` you swipe down to dismiss, with a
/// close button drawn into its own top bar and every action laid out as a row of icon buttons.
/// Here it is a plain `NavigationStack` push: the system back button and the edge-swipe do the
/// dismissing, and the actions live in a toolbar `Menu` — Edit included, which on Android sits
/// in the row because Android's sheet has no toolbar to put it in.
struct HabitDetailView: View {
    @StateObject private var viewModel: HabitDetailViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    @State private var pendingArchive = false
    @State private var pendingDelete = false

    init(
        habitId: String,
        repository: HabitRepository,
        toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase,
        archiveHabitUseCase: ArchiveHabitUseCase,
        unarchiveHabitUseCase: UnarchiveHabitUseCase,
        deleteHabitUseCase: DeleteHabitUseCase,
        habitReminderScheduler: HabitReminderScheduling,
        routineWidgetRefresher: RoutineWidgetRefreshing
    ) {
        _viewModel = StateObject(wrappedValue: HabitDetailViewModel(
            habitId: habitId,
            repository: repository,
            toggleHabitCompletionUseCase: toggleHabitCompletionUseCase,
            archiveHabitUseCase: archiveHabitUseCase,
            unarchiveHabitUseCase: unarchiveHabitUseCase,
            deleteHabitUseCase: deleteHabitUseCase,
            habitReminderScheduler: habitReminderScheduler,
            routineWidgetRefresher: routineWidgetRefresher
        ))
    }

    private var accentColor: Color {
        HabitPalette.color(at: viewModel.uiState.habit?.colorIndex ?? 0)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgDark.ignoresSafeArea())
            .navigationTitle(viewModel.uiState.habit?.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { actionsMenu } }
            .onAppear { viewModel.onAppear() }
            .onChange(of: viewModel.uiState.shouldDismiss) { shouldDismiss in
                if shouldDismiss { dismiss() }
            }
            .confirmationDialog(
                "¿Archivar este hábito?",
                isPresented: $pendingArchive,
                titleVisibility: .visible
            ) {
                Button("Archivar") { viewModel.onArchive() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Pasa al filtro de Archivados y deja de recordarte. Su historial se conserva — puedes restaurarlo cuando quieras.")
            }
            .confirmationDialog(
                "¿Borrar este hábito?",
                isPresented: $pendingDelete,
                titleVisibility: .visible
            ) {
                Button("Borrar", role: .destructive) { viewModel.onDelete() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Esta acción no se puede deshacer. Se pierde todo su historial de forma permanente.")
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.uiState.isLoading {
            ProgressView().tint(.accentPurple)
        } else if let habit = viewModel.uiState.habit {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header(habit)
                    heatmapSection(habit)
                    statsRow
                    Divider().background(Color.outline.opacity(0.4))
                    calendarSection(habit)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        } else {
            Text("Este hábito ya no existe.")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
    }

    private func header(_ habit: Habit) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: HabitIcons.symbol(for: habit.iconKey))
                .font(.system(size: 20))
                .foregroundColor(accentColor)
                .frame(width: 40, height: 40)
                .background(accentColor.opacity(0.16))
                .cornerRadius(10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if habit.isArchived {
                    Label("Archivado", systemImage: "archivebox.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                Text(habit.description?.isEmpty == false ? habit.description! : String(localized: "Sin descripción"))
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                Text(dateRangeLabel(habit))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
    }

    private func heatmapSection(_ habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Últimos 6 meses")
            HabitHeatmapView(
                startDate: habit.startDate,
                endDate: habit.endDate,
                completions: viewModel.uiState.completions,
                accentColor: accentColor,
                weeks: Self.detailHeatmapWeeks,
                today: viewModel.currentToday,
                showLabels: true,
                calendar: viewModel.currentCalendar
            )
            if let selected = viewModel.uiState.selectedDate {
                selectedDayCallout(selected)
            }
        }
    }

    private func selectedDayCallout(_ date: Date) -> some View {
        let isCompleted = viewModel.uiState.completions.contains(date)
        return HStack {
            Text("Día seleccionado")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                .font(.system(size: 12))
                .foregroundColor(.textPrimary)
            Text(isCompleted ? "Completado" : "No completado")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isCompleted ? accentColor : .textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.surface)
        .cornerRadius(10)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statChip(
                systemImage: "flame.fill",
                value: viewModel.uiState.streak.current,
                caption: "Racha actual",
                tint: accentColor
            )
            statChip(
                systemImage: "trophy.fill",
                value: viewModel.uiState.streak.best,
                caption: "Mejor racha",
                tint: .textSecondary
            )
            statChip(
                systemImage: "checkmark.seal.fill",
                value: viewModel.uiState.completions.count,
                caption: "Días marcados",
                tint: .textSecondary
            )
        }
    }

    private func statChip(systemImage: String, value: Int, caption: LocalizedStringKey, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundColor(tint)
                Text(value, format: .number)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            Text(caption)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.surface)
        .cornerRadius(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(caption))
        .accessibilityValue(Text(value, format: .number))
    }

    private func calendarSection(_ habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(monthLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Button { viewModel.onMonthChanged(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Mes anterior")

                Button { viewModel.onMonthChanged(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Mes siguiente")
            }

            HabitCalendarMonthView(
                month: viewModel.uiState.visibleMonth,
                completions: viewModel.uiState.completions,
                today: viewModel.currentToday,
                habit: habit,
                accentColor: accentColor,
                calendar: viewModel.currentCalendar,
                onDayTap: { viewModel.onDayTap($0) }
            )

            Text("Toca cualquier día para marcarlo o desmarcarlo. Los días futuros y los que quedan fuera del período del hábito no se pueden marcar.")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary.opacity(0.8))
        }
        .padding(.bottom, 16)
    }

    private var actionsMenu: some View {
        Menu {
            Button("Editar", systemImage: "pencil") {
                if let id = viewModel.uiState.habit?.id {
                    router.push(.habitEditor(habitId: id))
                }
            }
            if viewModel.uiState.habit?.isArchived == true {
                Button("Restaurar", systemImage: "arrow.uturn.backward") { viewModel.onUnarchive() }
            } else {
                Button("Archivar", systemImage: "archivebox") { pendingArchive = true }
            }
            Button("Borrar", systemImage: "trash", role: .destructive) { pendingDelete = true }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.textPrimary)
        }
        .accessibilityLabel("Acciones del hábito")
    }

    // MARK: - Helpers

    private static let detailHeatmapWeeks = 26

    /// "Marzo de 2026" / "March 2026". The format follows the user's locale; only the first
    /// letter is forced to uppercase, since Spanish month names are lowercase.
    private var monthLabel: String {
        let formatted = viewModel.uiState.visibleMonth.formatted(.dateTime.month(.wide).year())
        return formatted.prefix(1).uppercased() + formatted.dropFirst()
    }

    private func dateRangeLabel(_ habit: Habit) -> String {
        let start = habit.startDate.formatted(.dateTime.day().month(.abbreviated).year())
        guard let endDate = habit.endDate else { return String(localized: "Desde el \(start)") }
        let end = endDate.formatted(.dateTime.day().month(.abbreviated).year())
        return String(localized: "Del \(start) al \(end)")
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.textSecondary)
    }
}

// MARK: - Preview

/// In-memory stand-in so the preview renders without SwiftData, following the pattern the
/// other previews in this project already use.
private final class PreviewHabitRepository: HabitRepository {
    private var habit: Habit
    private var completions: Set<Date>

    init(habit: Habit, completions: Set<Date>) {
        self.habit = habit
        self.completions = completions
    }

    func fetchActiveHabits() async throws -> [Habit] { habit.isArchived ? [] : [habit] }
    func fetchArchivedHabits() async throws -> [Habit] { habit.isArchived ? [habit] : [] }
    func fetchCompletions(habitId: String) async throws -> [Date] { Array(completions) }
    func fetchAllCompletionDates() async throws -> [Date] { Array(completions) }
    func countActiveHabits() async throws -> Int { habit.isArchived ? 0 : 1 }
    func fetchHabit(id: String) async throws -> Habit? { id == habit.id ? habit : nil }
    func saveHabit(_ habit: Habit) async throws { self.habit = habit }
    func setCompletion(habitId: String, date: Date, completed: Bool) async throws {
        let day = Calendar.current.startOfDay(for: date)
        if completed { completions.insert(day) } else { completions.remove(day) }
    }
    func isCompleted(habitId: String, date: Date) async throws -> Bool {
        completions.contains(Calendar.current.startOfDay(for: date))
    }
    func archiveHabit(id: String) async throws { habit.isArchived = true }
    func unarchiveHabit(id: String) async throws { habit.isArchived = false }
    func deleteHabit(id: String) async throws { completions = [] }
}

#Preview("Detalle del hábito") {
    let calendar = Calendar.current
    let today = Date()
    let habit = Habit(
        id: "preview",
        title: "Entrenar",
        description: "20 minutos de cardio, todos los días.",
        iconKey: "dumbbell",
        colorIndex: 4,
        startDate: calendar.date(byAdding: .month, value: -3, to: today)!,
        endDate: nil,
        templateId: nil,
        coverAnimeSlug: nil,
        createdAt: today
    )
    let completions = Set(
        [0, 1, 2, 4, 5, 8, 11, 12, 13, 14, 20, 21, 30].compactMap {
            calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: today))
        }
    )
    let repository = PreviewHabitRepository(habit: habit, completions: completions)

    return NavigationStack {
        HabitDetailView(
            habitId: "preview",
            repository: repository,
            toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase(repository: repository),
            archiveHabitUseCase: ArchiveHabitUseCase(repository: repository),
            unarchiveHabitUseCase: UnarchiveHabitUseCase(repository: repository),
            deleteHabitUseCase: DeleteHabitUseCase(repository: repository),
            habitReminderScheduler: HabitReminderScheduler(),
            routineWidgetRefresher: NoopRoutineWidgetRefresher()
        )
        .environmentObject(AppRouter())
    }
    .preferredColorScheme(.dark)
}
