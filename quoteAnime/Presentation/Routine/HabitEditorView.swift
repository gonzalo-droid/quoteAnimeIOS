import SwiftUI

struct HabitEditorView: View {
    @StateObject private var viewModel: HabitEditorViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @State private var showIconPicker = false

    private let templates = DefaultHabitTemplates.all
    private let premiumGate: PremiumGate

    init(
        habitId: String?,
        createHabitUseCase: CreateHabitUseCase,
        updateHabitUseCase: UpdateHabitUseCase,
        habitRepository: HabitRepository,
        habitReminderScheduler: HabitReminderScheduler,
        notificationScheduler: NotificationScheduler,
        premiumGate: PremiumGate
    ) {
        _viewModel = StateObject(wrappedValue: HabitEditorViewModel(
            habitId: habitId,
            createHabitUseCase: createHabitUseCase,
            updateHabitUseCase: updateHabitUseCase,
            habitRepository: habitRepository,
            habitReminderScheduler: habitReminderScheduler,
            notificationScheduler: notificationScheduler
        ))
        self.premiumGate = premiumGate
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if !viewModel.uiState.isEditing {
                        templateRow
                    }
                    titleField
                    descriptionField
                    iconPicker
                    colorPicker
                    dateField
                    reminderSection
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDark.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $showIconPicker) {
            HabitIconPickerView(selectedKey: $viewModel.uiState.iconKey)
        }
        .alert(
            "Límite alcanzado",
            isPresented: Binding(
                get: { viewModel.limitReachedMessage != nil },
                set: { if !$0 { viewModel.limitReachedMessage = nil } }
            )
        ) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(viewModel.limitReachedMessage ?? "")
        }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 44, height: 44)
            }

            Text(viewModel.uiState.isEditing ? "Editar hábito" : "Nuevo hábito")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            Button {
                viewModel.save { dismiss() }
            } label: {
                if viewModel.uiState.isSaving {
                    ProgressView().tint(.accentPurple)
                        .frame(width: 44, height: 44)
                } else {
                    Text("Guardar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(viewModel.uiState.canSave ? .accentPurple : .textSecondary)
                        .frame(width: 72, height: 44)
                }
            }
            .disabled(!viewModel.uiState.canSave || viewModel.uiState.isSaving)
        }
        .frame(height: 52)
        .background(Color.bgDark)
    }

    private var templateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Sugerencias")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(templates) { template in
                        let isLocked = template.isPremiumOnly && !premiumGate.isPremium
                        Button {
                            if isLocked {
                                router.push(.paywall)
                            } else {
                                viewModel.onTemplateSelected(template)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isLocked ? "lock.fill" : HabitIcons.symbol(for: template.iconKey))
                                Text(template.title)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(isLocked ? .textSecondary : .textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.surface)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.outline.opacity(0.4), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Nombre")
            TextField("", text: $viewModel.uiState.title, prompt: Text("Ej: Meditar 10 minutos").foregroundColor(.textSecondary))
                .foregroundColor(.textPrimary)
                .padding(12)
                .background(Color.surface)
                .cornerRadius(12)
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Descripción (opcional)")
            TextField("", text: $viewModel.uiState.description, prompt: Text("Agregá contexto o tu motivación").foregroundColor(.textSecondary), axis: .vertical)
                .foregroundColor(.textPrimary)
                .lineLimit(2...4)
                .padding(12)
                .background(Color.surface)
                .cornerRadius(12)
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Ícono")
            Button { showIconPicker = true } label: {
                HStack {
                    Image(systemName: HabitIcons.symbol(for: viewModel.uiState.iconKey))
                        .font(.system(size: 20))
                        .foregroundColor(HabitPalette.color(at: viewModel.uiState.colorIndex))
                    Text("Elegir ícono")
                        .font(.system(size: 14))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.textSecondary)
                }
                .padding(12)
                .background(Color.surface)
                .cornerRadius(12)
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Color")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(HabitPalette.colors.indices, id: \.self) { index in
                    Button {
                        viewModel.uiState.colorIndex = index
                    } label: {
                        Circle()
                            .fill(HabitPalette.colors[index])
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: viewModel.uiState.colorIndex == index ? 2 : 0)
                            )
                    }
                }
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Fecha de inicio")
            DatePicker(
                "",
                selection: $viewModel.uiState.startDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .colorScheme(.dark)
            .padding(12)
            .background(Color.surface)
            .cornerRadius(12)
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Recordatorio")
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { viewModel.uiState.reminderEnabled },
                        set: { viewModel.onReminderToggled($0) }
                    )
                )
                .labelsHidden()
                .tint(.accentPurple)
            }

            if viewModel.uiState.reminderEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        ForEach(Self.weekdaySymbols, id: \.weekday) { symbol in
                            let isSelected = viewModel.uiState.reminderWeekdays.contains(symbol.weekday)
                            Button {
                                viewModel.onWeekdayToggled(symbol.weekday)
                            } label: {
                                Text(symbol.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(isSelected ? .bgDark : .textPrimary)
                                    .frame(width: 32, height: 32)
                                    .background(isSelected ? Color.accentPurple : Color.surface)
                                    .clipShape(Circle())
                            }
                        }
                    }

                    DatePicker(
                        "",
                        selection: $viewModel.uiState.reminderTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .colorScheme(.dark)
                }
                .padding(12)
                .background(Color.surface)
                .cornerRadius(12)
            }
        }
    }

    /// `Calendar` weekday numbering: 1 = Sunday ... 7 = Saturday.
    private static let weekdaySymbols: [(weekday: Int, label: String)] = [
        (1, "D"), (2, "L"), (3, "M"), (4, "X"), (5, "J"), (6, "V"), (7, "S")
    ]

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.textSecondary)
    }
}

// MARK: - Icon Picker

private struct HabitIconPickerView: View {
    @Binding var selectedKey: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(HabitIcons.categories) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textSecondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                                ForEach(category.keys, id: \.self) { key in
                                    Button {
                                        selectedKey = key
                                        dismiss()
                                    } label: {
                                        Image(systemName: HabitIcons.symbol(for: key))
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedKey == key ? .accentPurple : .textPrimary)
                                            .frame(width: 44, height: 44)
                                            .background(Color.surface)
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selectedKey == key ? Color.accentPurple : Color.clear, lineWidth: 1.5)
                                            )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color.bgDark.ignoresSafeArea())
            .navigationTitle("Elegir ícono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { dismiss() }
                        .foregroundColor(.accentPurple)
                }
            }
        }
    }
}
