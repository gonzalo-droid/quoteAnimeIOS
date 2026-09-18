import SwiftUI
import Combine

struct HabitEditorUiState {
    var title: String = ""
    var description: String = ""
    var iconKey: String = HabitIcons.allKeys.first ?? "task_alt"
    var colorIndex: Int = 0
    var startDate: Date = Date()
    /// An end date is opt-in, like Android's `habit_editor_has_end_date` switch. When off,
    /// `Habit.endDate` is nil and the habit runs indefinitely.
    var hasEndDate: Bool = false
    var endDate: Date = Date()
    var reminderEnabled: Bool = false
    var reminderWeekdays: Set<Int> = []
    var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    /// The suggestion the habit started from, as on Android: set by `onTemplateSelected`, loaded
    /// back when editing, persisted on `Habit.templateId` and reported as `habit_created`'s
    /// `template_id` (nil = `"custom"`).
    var templateId: String?
    /// The suggestion's theme, shown as `ThemedSuggestionPreview` and saved as
    /// `Habit.coverAnimeSlug` — Android's `HabitEditorUiState.themeKey`.
    var themeKey: String?
    var isSaving: Bool = false
    var isEditing: Bool = false
    var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// The switch is on but no weekday is picked: nothing would ever fire. The editor says so
    /// under the weekday row, and the use cases save it as "no reminder".
    var reminderHasNoWeekdays: Bool { reminderEnabled && reminderWeekdays.isEmpty }
}

/// One alert slot for everything the editor has to tell the user: every reason a save can be
/// refused (each maps to one of `CreateHabitError` / `UpdateHabitError`), plus a reminder that
/// can't be turned on because notifications are denied.
struct HabitEditorAlert: Identifiable, Equatable {
    enum Reason: Equatable {
        case habitLimitReached(max: Int)
        case blankTitle
        case invalidDateRange
        case habitNotFound
        /// Android shows `habit_editor_reminder_permission_denied_message` in a snackbar with a
        /// "Settings" action; iOS has no snackbar, so it's an alert with the same two choices.
        case reminderPermissionDenied
    }

    let id = UUID()
    /// What went wrong, independent of the language the text is shown in — tests assert this.
    let reason: Reason

    var title: String {
        switch reason {
        case .habitLimitReached: return String(localized: "Límite alcanzado")
        case .blankTitle: return String(localized: "Falta el nombre")
        case .invalidDateRange: return String(localized: "Fechas inválidas")
        case .habitNotFound: return String(localized: "No se pudo guardar")
        case .reminderPermissionDenied: return String(localized: "Permiso de notificaciones")
        }
    }

    var message: String {
        switch reason {
        case .habitLimitReached(let max):
            return String(localized: "Con el plan gratuito puedes tener \(max) hábitos activos a la vez. Archiva uno o pásate a premium para agregar más.")
        case .blankTitle:
            return String(localized: "Ponle un nombre al hábito para poder guardarlo.")
        case .invalidDateRange:
            return String(localized: "La fecha de fin no puede ser anterior a la de inicio.")
        case .habitNotFound:
            return String(localized: "Este hábito ya no existe.")
        case .reminderPermissionDenied:
            return String(localized: "Las notificaciones están desactivadas, así que el recordatorio no funcionará. Actívalas desde Ajustes.")
        }
    }

    /// Only a denied permission can be fixed outside the app, so only that alert links to Settings.
    var offersSystemSettings: Bool { reason == .reminderPermissionDenied }
}

@MainActor
final class HabitEditorViewModel: ObservableObject {
    @Published var uiState = HabitEditorUiState()
    @Published var alert: HabitEditorAlert?
    /// The suggestion chips: bundled at once, replaced by `/habitTemplates` when it answers.
    @Published private(set) var templates: [HabitTemplate]

    private let createHabitUseCase: CreateHabitUseCase
    private let updateHabitUseCase: UpdateHabitUseCase
    private let habitRepository: HabitRepository
    private let habitReminderScheduler: HabitReminderScheduling
    private let routineWidgetRefresher: RoutineWidgetRefreshing
    private let analytics: RoutineAnalytics
    private let getHabitTemplates: GetHabitTemplatesUseCase
    private let habitId: String?
    private var existingHabit: Habit?

    init(
        habitId: String?,
        createHabitUseCase: CreateHabitUseCase,
        updateHabitUseCase: UpdateHabitUseCase,
        habitRepository: HabitRepository,
        habitReminderScheduler: HabitReminderScheduling,
        routineWidgetRefresher: RoutineWidgetRefreshing,
        analytics: RoutineAnalytics = NoopRoutineAnalytics(),
        getHabitTemplates: GetHabitTemplatesUseCase = GetHabitTemplatesUseCase()
    ) {
        self.habitId = habitId
        self.getHabitTemplates = getHabitTemplates
        self.templates = getHabitTemplates.bundled
        self.analytics = analytics
        self.createHabitUseCase = createHabitUseCase
        self.updateHabitUseCase = updateHabitUseCase
        self.habitRepository = habitRepository
        self.habitReminderScheduler = habitReminderScheduler
        self.routineWidgetRefresher = routineWidgetRefresher
        self.uiState.isEditing = habitId != nil
    }

    func onAppear() {
        guard let habitId, existingHabit == nil else { return }
        Task {
            if let habit = try? await habitRepository.fetchHabit(id: habitId) {
                existingHabit = habit
                uiState.title = habit.title
                uiState.description = habit.description ?? ""
                uiState.templateId = habit.templateId
                uiState.themeKey = habit.coverAnimeSlug
                uiState.iconKey = habit.iconKey
                uiState.colorIndex = habit.colorIndex
                uiState.startDate = habit.startDate
                uiState.hasEndDate = habit.endDate != nil
                uiState.endDate = habit.endDate ?? habit.startDate
                // A habit saved before the use cases normalised the reminder can still be
                // "on" with no weekdays; it never fired, so it opens as off.
                uiState.reminderEnabled = habit.reminderEnabled && !habit.reminderWeekdays.isEmpty
                uiState.reminderWeekdays = habit.reminderWeekdays
                uiState.reminderTime = Calendar.current.date(
                    bySettingHour: habit.reminderHour, minute: habit.reminderMinute, second: 0, of: Date()
                ) ?? uiState.reminderTime
            }
        }
    }

    /// Android's `onTemplateSelected` (`64f9b8b`): picking a suggestion *applies* it — its title,
    /// its theme description (when it has one), icon, colour and cover all replace what the form
    /// had. Picking one is an explicit request for that suggestion, and the title only used to be
    /// kept when non-empty because the form started blank; now it starts from a suggestion.
    func onTemplateSelected(_ template: HabitTemplate) {
        uiState.templateId = template.id
        uiState.themeKey = template.themeKey
        uiState.iconKey = template.iconKey
        if let themeColorIndex = template.themeColorIndex {
            uiState.colorIndex = themeColorIndex
        }
        uiState.title = template.title
        if let description = HabitThemeImages.description(for: template.themeKey) {
            uiState.description = description
        }
    }

    /// A new habit starts from the first suggestion the user can use (`64f9b8b`: the suggestions
    /// are all themed, so there is no blank default any more). Never while editing, never once a
    /// suggestion was applied, and never a locked one — same guards as Android's `LaunchedEffect`.
    func applyDefaultTemplate(from templates: [HabitTemplate], isPremium: Bool) {
        guard !uiState.isEditing, uiState.templateId == nil,
              let first = templates.first(where: { !$0.isLocked(isPremium: isPremium) })
        else { return }
        onTemplateSelected(first)
    }

    /// Swaps the bundled chips for the remote ones once they arrive, then applies the first
    /// usable one if nothing was applied yet. A suggestion already applied — by the user or by
    /// the automatic default — is never swapped for another, same as Android's `templateId == null`
    /// guard; if the remote list doesn't contain it, the form keeps its values and no chip is
    /// marked. Editing an existing habit shows no chips, so it doesn't ask the network at all.
    /// `isPremium` is read after the fetch, not before it.
    func loadTemplates(isPremium: () -> Bool) async {
        guard !uiState.isEditing else { return }
        let loaded = await getHabitTemplates.execute()
        if loaded != templates {
            templates = loaded
        }
        applyDefaultTemplate(from: templates, isPremium: isPremium())
    }

    /// Keeps the pair consistent while editing: moving the start past the end drags the end
    /// with it, so the picker can never hand the use case an inverted range.
    func onStartDateChanged(_ date: Date) {
        uiState.startDate = date
        if uiState.hasEndDate, uiState.endDate < date {
            uiState.endDate = date
        }
    }

    func onEndDateEnabled(_ enabled: Bool) {
        uiState.hasEndDate = enabled
        if enabled, uiState.endDate < uiState.startDate {
            uiState.endDate = uiState.startDate
        }
    }

    /// The switch turns on optimistically and turns back off if notifications are denied — and
    /// then says why, instead of silently flipping back.
    ///
    /// Turning it on with no weekdays picked selects all seven, as Android's editor starts
    /// (`reminderDays = DayOfWeek.entries.toSet()`): an armed switch must always fire somewhere.
    func onReminderToggled(_ enabled: Bool) {
        uiState.reminderEnabled = enabled
        guard enabled else { return }
        if uiState.reminderWeekdays.isEmpty {
            uiState.reminderWeekdays = Set(1...7)
        }
        Task {
            let granted = await habitReminderScheduler.requestPermission()
            guard !granted else { return }
            uiState.reminderEnabled = false
            alert = HabitEditorAlert(reason: .reminderPermissionDenied)
        }
    }

    func onWeekdayToggled(_ weekday: Int) {
        if uiState.reminderWeekdays.contains(weekday) {
            uiState.reminderWeekdays.remove(weekday)
        } else {
            uiState.reminderWeekdays.insert(weekday)
        }
    }

    func save(onSaved: @escaping () -> Void) {
        guard uiState.canSave, !uiState.isSaving else { return }
        uiState.isSaving = true
        Task {
            do {
                let habit = buildHabit()
                // The use cases re-run every check and own the trimming, so what gets saved is
                // what they return — never the raw form values.
                let isNew = existingHabit == nil
                let saved = isNew
                    ? try await createHabitUseCase.execute(habit)
                    : try await updateHabitUseCase.execute(habit)
                await habitReminderScheduler.schedule(habit: saved)
                if isNew {
                    // Only a successful creation counts, as on Android; an edit is never reported.
                    analytics.trackHabitCreated(
                        templateId: saved.templateId,
                        hasReminder: saved.reminderEnabled,
                        hasEndDate: uiState.hasEndDate
                    )
                }
                await routineWidgetRefresher.refresh()
                uiState.isSaving = false
                onSaved()
            } catch let error as CreateHabitError {
                uiState.isSaving = false
                alert = Self.alert(for: error)
            } catch let error as UpdateHabitError {
                uiState.isSaving = false
                alert = Self.alert(for: error)
            } catch {
                uiState.isSaving = false
                print("[HabitEditorViewModel] save error: \(error)")
            }
        }
    }

    private func buildHabit() -> Habit {
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: uiState.reminderTime)
        return Habit(
            id: existingHabit?.id ?? UUID().uuidString,
            title: uiState.title,
            description: uiState.description,
            iconKey: uiState.iconKey,
            colorIndex: uiState.colorIndex,
            startDate: uiState.startDate,
            endDate: uiState.hasEndDate ? uiState.endDate : nil,
            templateId: uiState.templateId,
            coverAnimeSlug: uiState.themeKey,
            // Carried forward deliberately: `saveHabit` upserts the whole record, so dropping
            // this would restore an archived habit just by opening and saving its editor.
            isArchived: existingHabit?.isArchived ?? false,
            createdAt: existingHabit?.createdAt ?? Date(),
            reminderEnabled: uiState.reminderEnabled,
            reminderWeekdays: uiState.reminderWeekdays,
            reminderHour: timeComponents.hour ?? 9,
            reminderMinute: timeComponents.minute ?? 0
        )
    }

    private static func alert(for error: CreateHabitError) -> HabitEditorAlert {
        switch error {
        case .habitLimitReached(let max):
            return HabitEditorAlert(reason: .habitLimitReached(max: max))
        case .blankTitle:
            return HabitEditorAlert(reason: .blankTitle)
        case .invalidDateRange:
            return HabitEditorAlert(reason: .invalidDateRange)
        }
    }

    private static func alert(for error: UpdateHabitError) -> HabitEditorAlert {
        switch error {
        case .blankTitle:
            return HabitEditorAlert(reason: .blankTitle)
        case .invalidDateRange:
            return HabitEditorAlert(reason: .invalidDateRange)
        case .habitNotFound:
            return HabitEditorAlert(reason: .habitNotFound)
        }
    }
}
