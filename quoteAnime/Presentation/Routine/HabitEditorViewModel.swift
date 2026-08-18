import SwiftUI
import Combine

struct HabitEditorUiState {
    var title: String = ""
    var description: String = ""
    var iconKey: String = HabitIcons.allKeys.first ?? "task_alt"
    var colorIndex: Int = 0
    var startDate: Date = Date()
    var reminderEnabled: Bool = false
    var reminderWeekdays: Set<Int> = []
    var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var isSaving: Bool = false
    var isEditing: Bool = false
    var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

@MainActor
final class HabitEditorViewModel: ObservableObject {
    @Published var uiState = HabitEditorUiState()
    @Published var limitReachedMessage: String?

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
                let trimmedDescription = uiState.description.trimmingCharacters(in: .whitespacesAndNewlines)
                let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: uiState.reminderTime)
                let habit = Habit(
                    id: existingHabit?.id ?? UUID().uuidString,
                    title: uiState.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    iconKey: uiState.iconKey,
                    colorIndex: uiState.colorIndex,
                    startDate: uiState.startDate,
                    templateId: existingHabit?.templateId,
                    coverAnimeSlug: existingHabit?.coverAnimeSlug,
                    createdAt: existingHabit?.createdAt ?? Date(),
                    reminderEnabled: uiState.reminderEnabled,
                    reminderWeekdays: uiState.reminderWeekdays,
                    reminderHour: timeComponents.hour ?? 9,
                    reminderMinute: timeComponents.minute ?? 0
                )
                if existingHabit != nil {
                    try await updateHabitUseCase.execute(habit)
                } else {
                    try await createHabitUseCase.execute(habit)
                }
                await habitReminderScheduler.schedule(habit: habit)
                uiState.isSaving = false
                onSaved()
            } catch CreateHabitError.habitLimitReached {
                uiState.isSaving = false
                limitReachedMessage = "Llegaste al límite de hábitos gratuitos"
            } catch {
                uiState.isSaving = false
                print("[HabitEditorViewModel] save error: \(error)")
            }
        }
    }
}
