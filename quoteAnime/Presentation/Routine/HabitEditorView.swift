import SwiftUI

struct HabitEditorView: View {
    @StateObject private var viewModel: HabitEditorViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @State private var showIconPicker = false

    private let templates = DefaultHabitTemplates.all
    /// Observed so a template unlocked mid-session stops showing its padlock.
    @ObservedObject private var premiumGate: PremiumGate

    init(
        habitId: String?,
        createHabitUseCase: CreateHabitUseCase,
        updateHabitUseCase: UpdateHabitUseCase,
        habitRepository: HabitRepository,
        habitReminderScheduler: HabitReminderScheduling,
        routineWidgetRefresher: RoutineWidgetRefreshing,
        premiumGate: PremiumGate,
        analytics: RoutineAnalytics
    ) {
        _viewModel = StateObject(wrappedValue: HabitEditorViewModel(
            habitId: habitId,
            createHabitUseCase: createHabitUseCase,
            updateHabitUseCase: updateHabitUseCase,
            habitRepository: habitRepository,
            habitReminderScheduler: habitReminderScheduler,
            routineWidgetRefresher: routineWidgetRefresher,
            analytics: analytics
        ))
        _premiumGate = ObservedObject(wrappedValue: premiumGate)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if !viewModel.uiState.isEditing {
                        templateRow
                    }
                    if let themeKey = viewModel.uiState.themeKey {
                        ThemedSuggestionPreview(
                            iconKey: viewModel.uiState.iconKey,
                            title: viewModel.uiState.title,
                            description: viewModel.uiState.description,
                            themeKey: themeKey,
                            accentColor: HabitPalette.color(at: viewModel.uiState.colorIndex)
                        )
                    }
                    titleField
                    descriptionField
                    iconPicker
                    colorPicker
                    datesSection
                    reminderSection
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDark.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            viewModel.onAppear()
            viewModel.applyDefaultTemplate(from: templates, isPremium: premiumGate.isPremium)
        }
        .sheet(isPresented: $showIconPicker) {
            HabitIconPickerView(selectedKey: $viewModel.uiState.iconKey)
        }
        .alert(
            viewModel.alert?.title ?? "",
            isPresented: Binding(
                get: { viewModel.alert != nil },
                set: { if !$0 { viewModel.alert = nil } }
            )
        ) {
            if viewModel.alert?.offersSystemSettings == true {
                Button("Ajustes") { openNotificationSettings() }
                    .keyboardShortcut(.defaultAction)
                Button("Cancelar", role: .cancel) {}
            } else {
                Button("Entendido", role: .cancel) {}
            }
        } message: {
            Text(viewModel.alert?.message ?? "")
        }
    }

    /// Opens Settings through the notification-specific URL (iOS 16+). On the iOS 26.3
    /// simulator it lands on the app's page, with the Notifications row showing "Off" — the same
    /// destination Android's `ACTION_APPLICATION_DETAILS_SETTINGS` reaches.
    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
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
            .accessibilityLabel("Volver")

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
                        let isLocked = template.isLocked(isPremium: premiumGate.isPremium)
                        // Android's `FilterChip(selected = templateId == template.id)`: now that a
                        // new habit starts from a suggestion, the chip has to say which one.
                        let isSelected = viewModel.uiState.templateId == template.id
                        Button {
                            if isLocked {
                                router.push(.paywall)
                            } else {
                                viewModel.onTemplateSelected(template)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isLocked ? "lock.fill" : HabitIcons.symbol(for: template.iconKey))
                                Text(verbatim: template.title)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(isLocked ? .textSecondary : (isSelected ? .bgDark : .textPrimary))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.accentPurple : Color.surface)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isSelected ? Color.accentPurple : Color.outline.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityHint(isLocked ? Text("Sugerencia exclusiva para premium") : Text(verbatim: ""))
                    }
                }
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Nombre")
            TextField("Nombre", text: $viewModel.uiState.title, prompt: Text("Ej: Meditar 10 minutos").foregroundColor(.textSecondary))
                .foregroundColor(.textPrimary)
                .padding(12)
                .background(Color.surface)
                .cornerRadius(12)
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Descripción (opcional)")
            TextField("Descripción", text: $viewModel.uiState.description, prompt: Text("Agrega contexto o tu motivación").foregroundColor(.textSecondary), axis: .vertical)
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
                        .accessibilityHidden(true)
                    Text("Elegir ícono")
                        .font(.system(size: 14))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(12)
                .background(Color.surface)
                .cornerRadius(12)
            }
            // "Elegir ícono, Entrenar": the glyph alone would read as the SF Symbol's own name.
            .accessibilityValue(Text(HabitIcons.label(for: viewModel.uiState.iconKey)))
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
                    .accessibilityLabel(Text(HabitPalette.accessibilityLabel(at: index)))
                    .accessibilityAddTraits(viewModel.uiState.colorIndex == index ? .isSelected : [])
                }
            }
        }
    }

    /// Start date plus an opt-in end date, mirroring Android's `habit_editor_has_end_date`
    /// switch. The end picker's range starts at `startDate`, so an inverted range can't be
    /// produced here at all — `CreateHabitUseCase`/`UpdateHabitUseCase` still reject one as
    /// the backstop.
    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Fecha de inicio")
            DatePicker(
                "Fecha de inicio",
                selection: Binding(
                    get: { viewModel.uiState.startDate },
                    set: { viewModel.onStartDateChanged($0) }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .colorScheme(.dark)
            .padding(12)
            .background(Color.surface)
            .cornerRadius(12)

            HStack {
                sectionLabel("Ponerle fecha de fin")
                Spacer()
                Toggle(
                    "Ponerle fecha de fin",
                    isOn: Binding(
                        get: { viewModel.uiState.hasEndDate },
                        set: { viewModel.onEndDateEnabled($0) }
                    )
                )
                .labelsHidden()
                .tint(.accentPurple)
            }
            .padding(.top, 8)

            if viewModel.uiState.hasEndDate {
                DatePicker(
                    "Fecha de fin",
                    selection: $viewModel.uiState.endDate,
                    in: viewModel.uiState.startDate...,
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
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Recordatorio")
                Spacer()
                Toggle(
                    "Recordatorio",
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
                        ForEach(weekdaySymbols, id: \.weekday) { symbol in
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
                            .accessibilityLabel(symbol.name)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }

                    DatePicker(
                        "Hora",
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

    /// `Calendar` weekday numbering: 1 = Sunday ... 7 = Saturday, kept Sunday-first as before.
    /// Initials and names come from the user's locale ("D L M X" in Spanish, "S M T W" in
    /// English) instead of a hardcoded Spanish list.
    private var weekdaySymbols: [(weekday: Int, label: String, name: String)] {
        let calendar = Calendar.current
        let initials = calendar.veryShortStandaloneWeekdaySymbols
        let names = calendar.standaloneWeekdaySymbols
        return (1...7).map { ($0, initials[$0 - 1], names[$0 - 1]) }
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.textSecondary)
    }
}

// MARK: - Icon Picker

private struct HabitIconPickerView: View {
    @Binding var selectedKey: String
    @Environment(\.dismiss) private var dismiss
    /// Android `1d9e231` filters the 126 icons by name — see `HabitIconSearch` for the rule.
    @State private var query = ""

    private var visibleCategories: [HabitIconCategory] {
        HabitIconSearch.filter(HabitIcons.categories, query: query) { key in
            HabitIcons.localizedLabel(for: key)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if visibleCategories.isEmpty {
                    noResults
                } else {
                    iconGrid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bgDark.ignoresSafeArea())
            .navigationTitle("Elegir ícono")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Buscar…")
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") { dismiss() }
                        .foregroundColor(.accentPurple)
                }
            }
        }
    }

    private var iconGrid: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(visibleCategories) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(category.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .accessibilityAddTraits(.isHeader)

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
                                // Android 4f8e6d2 names each icon (`describeIcon`); iOS also
                                // says which one is chosen, which TalkBack there does not.
                                .accessibilityLabel(Text(HabitIcons.label(for: key)))
                                .accessibilityAddTraits(selectedKey == key ? .isSelected : [])
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    /// Android's `habit_icon_picker_empty`. The stock `ContentUnavailableView` where it exists
    /// (iOS 17); the same title and glyph by hand on 16.
    @ViewBuilder
    private var noResults: some View {
        if #available(iOS 17, *) {
            ContentUnavailableView("No se encontraron íconos", systemImage: "magnifyingglass")
        } else {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.textSecondary)
                    .accessibilityHidden(true)
                Text("No se encontraron íconos")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
        }
    }
}

#Preview("Selector de íconos") {
    HabitIconPickerView(selectedKey: .constant("book"))
        .preferredColorScheme(.dark)
}
