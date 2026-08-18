import SwiftUI

struct RoutineView: View {
    @StateObject private var viewModel: RoutineViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    init(
        getActiveHabitsUseCase: GetActiveHabitsUseCase,
        getGlobalStreakUseCase: GetGlobalStreakUseCase,
        toggleHabitCompletionUseCase: ToggleHabitCompletionUseCase,
        premiumGate: PremiumGate
    ) {
        _viewModel = StateObject(wrappedValue: RoutineViewModel(
            getActiveHabitsUseCase: getActiveHabitsUseCase,
            getGlobalStreakUseCase: getGlobalStreakUseCase,
            toggleHabitCompletionUseCase: toggleHabitCompletionUseCase,
            premiumGate: premiumGate
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundColor(.textSecondary)
            Text("Todavía no tenés hábitos")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textPrimary)
            Text("Creá el primero para empezar a construir tu racha")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
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
            Spacer()
        }
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.uiState.habits) { item in
                    HabitCardView(
                        item: item,
                        onToggleToday: { viewModel.onToggleToday(item.habit.id) },
                        onTap: { router.push(.habitEditor(habitId: item.habit.id)) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }
}
