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
    var isSaving: Bool = false
    var isEditing: Bool = false
    var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// One alert slot for every reason a save can be refused — the limit, a blank title, an
/// inverted date range. Each maps to one of `CreateHabitError` / `UpdateHabitError`.
struct HabitEditorAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class HabitEditorViewModel: ObservableObject {
    @Published var uiState = HabitEditorUiState()
    @Published var alert: HabitEditorAlert?

    private let createHabitUseCase: CreateHabitUseCase
    private let updateHabitUseCase: UpdateHabitUseCase
    private let habitRepository: HabitRepository
    private let habitReminderScheduler: HabitReminderScheduler
    private let notificationScheduler: NotificationScheduler
    private let habitId: String?
    private var existingHabit: Habit?

    init(
        habitId: String?,
        createHabitUseCase: CreateHabitUseCase,
        updateHabitUseCase: UpdateHabitUseCase,
        habitRepository: HabitRepository,
        habitReminderScheduler: HabitReminderScheduler,
        notificationScheduler: NotificationScheduler
    ) {
        self.habitId = habitId
        self.createHabitUseCase = createHabitUseCase
        self.updateHabitUseCase = updateHabitUseCase
        self.habitRepository = habitRepository
        self.habitReminderScheduler = habitReminderScheduler
        self.notificationScheduler = notificationScheduler
        self.uiState.isEditing = habitId != nil
    }

    func onAppear() {
        guard let habitId, existingHabit == nil else { return }
        Task {
            if let habit = try? await habitRepository.fetchHabit(id: habitId) {
                existingHabit = habit
                uiState.title = habit.title
                uiState.description = habit.description ?? ""
                uiState.iconKey = habit.iconKey
                uiState.colorIndex = habit.colorIndex
                uiState.startDate = habit.startDate
                uiState.hasEndDate = habit.endDate != nil
                uiState.endDate = habit.endDate ?? habit.startDate
                uiState.reminderEnabled = habit.reminderEnabled
                uiState.reminderWeekdays = habit.reminderWeekdays
                uiState.reminderTime = Calendar.current.date(
                    bySettingHour: habit.reminderHour, minute: habit.reminderMinute, second: 0, of: Date()
                ) ?? uiState.reminderTime
            }
        }
    }

    func onTemplateSelected(_ template: HabitTemplate) {
        uiState.iconKey = template.iconKey
        if let themeColorIndex = template.themeColorIndex {
            uiState.colorIndex = themeColorIndex
        }
        if uiState.title.isEmpty {
            uiState.title = template.title
        }
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

    func onReminderToggled(_ enabled: Bool) {
        uiState.reminderEnabled = enabled
        guard enabled else { return }
        Task {
            let granted = await notificationScheduler.requestPermission()
            if !granted { uiState.reminderEnabled = false }
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
                let saved = existingHabit != nil
                    ? try await updateHabitUseCase.execute(habit)
                    : try await createHabitUseCase.execute(habit)
                await habitReminderScheduler.schedule(habit: saved)
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
            templateId: existingHabit?.templateId,
            coverAnimeSlug: existingHabit?.coverAnimeSlug,
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
            return HabitEditorAlert(
                title: "Límite alcanzado",
                message: "Con el plan gratuito podés tener \(max) hábitos activos a la vez. Archivá uno o pasate a premium para agregar más."
            )
        case .blankTitle:
            return blankTitleAlert
        case .invalidDateRange:
            return invalidDateRangeAlert
        }
    }

    private static func alert(for error: UpdateHabitError) -> HabitEditorAlert {
        switch error {
        case .blankTitle:
            return blankTitleAlert
        case .invalidDateRange:
            return invalidDateRangeAlert
        case .habitNotFound:
            return HabitEditorAlert(
                title: "No se pudo guardar",
                message: "Este hábito ya no existe."
            )
        }
    }

    private static let blankTitleAlert = HabitEditorAlert(
        title: "Falta el nombre",
        message: "Ponele un nombre al hábito para poder guardarlo."
    )

    private static let invalidDateRangeAlert = HabitEditorAlert(
        title: "Fechas inválidas",
        message: "La fecha de fin no puede ser anterior a la de inicio."
    )
}
