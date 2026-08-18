import SwiftUI

struct RoutineView: View {
    @StateObject private var viewModel: RoutineViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    init(
        getActiveHabitsUseCase: GetActiveHabitsUseCase,
        getArchivedHabitsUseCase: GetArchivedHabitsUseCase,
        getGlobalStreakUseCase: GetGlobalStreakUseCase,
        toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase,
        archiveHabitUseCase: ArchiveHabitUseCase,
        unarchiveHabitUseCase: UnarchiveHabitUseCase,
        deleteHabitUseCase: DeleteHabitUseCase,
        premiumGate: PremiumGate
    ) {
        _viewModel = StateObject(wrappedValue: RoutineViewModel(
            getActiveHabitsUseCase: getActiveHabitsUseCase,
            getArchivedHabitsUseCase: getArchivedHabitsUseCase,
            getGlobalStreakUseCase: getGlobalStreakUseCase,
            toggleHabitCompletionUseCase: toggleHabitCompletionUseCase,
            archiveHabitUseCase: archiveHabitUseCase,
            unarchiveHabitUseCase: unarchiveHabitUseCase,
            deleteHabitUseCase: deleteHabitUseCase,
            premiumGate: premiumGate
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            filterTabs

            if viewModel.uiState.isLoading {
                Spacer()
                ProgressView().tint(.accentPurple)
                Spacer()
            } else if viewModel.uiState.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDark.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { viewModel.onAppear() }
    }

    private var topBar: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(width: 44, height: 44)
                }

                Text("Mi Rutina")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    router.push(.habitEditor(habitId: nil))
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(viewModel.uiState.canAddHabit ? .textPrimary : .textSecondary)
                        .frame(width: 44, height: 44)
                }
                .disabled(!viewModel.uiState.canAddHabit)
            }
            .frame(height: 52)

            if viewModel.uiState.globalStreak.current > 0 {
                Label("\(viewModel.uiState.globalStreak.current) días seguidos", systemImage: "flame.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.accentPurple)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.bgDark)
    }

    private var filterTabs: some View {
        HStack(spacing: 8) {
            filterTab(title: "Activos", filter: .active)
            filterTab(title: "Archivados", filter: .archived)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func filterTab(title: String, filter: RoutineFilter) -> some View {
        let isSelected = viewModel.uiState.filter == filter
        return Button { viewModel.onFilterChanged(filter) } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .bgDark : .textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentPurple : Color.surface)
                .cornerRadius(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundColor(.textSecondary)
            Text(viewModel.uiState.filter == .active ? "Todavía no tenés hábitos" : "No archivaste ningún hábito")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text(
                viewModel.uiState.filter == .active
                    ? "Creá el primero para empezar a construir tu racha"
                    : "Los hábitos archivados guardan su historial — restauralos cuando quieras retomarlos"
            )
            .font(.system(size: 13))
            .foregroundColor(.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            if viewModel.uiState.filter == .active {
                Button {
                    router.push(.habitEditor(habitId: nil))
                } label: {
                    Text("Crear hábito")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.bgDark)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentPurple)
                        .cornerRadius(24)
                }
                .padding(.top, 4)
            }
            Spacer()
        }
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.uiState.habits) { item in
                    HabitCardView(
                        item: item,
                        isArchived: viewModel.uiState.filter == .archived,
                        onToggleToday: { viewModel.onToggleToday(item.habit.id) },
                        onTap: { router.push(.habitEditor(habitId: item.habit.id)) },
                        onArchive: { viewModel.onArchive(item.habit.id) },
                        onUnarchive: { viewModel.onUnarchive(item.habit.id) },
                        onDelete: { viewModel.onDelete(item.habit.id) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }
}
