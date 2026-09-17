import Foundation
import SwiftData

/// SwiftData record for a habit.
///
/// **Schema history / migration.** `endDate` was added after the first release. It is an
/// optional attribute with no uniqueness or relationship change, which is exactly the shape
/// SwiftData resolves with an *implicit lightweight migration* — the existing store gains a
/// nullable column and every stored habit reads back with `endDate == nil` (an
/// indefinite habit, the previous behaviour). No `VersionedSchema` / `SchemaMigrationPlan`
/// is needed, and adding one would mean freezing a copy of this class per version for a
/// change that carries no data transformation. Verified by installing the previous build,
/// creating habits and completions, then installing this build over it (see CHANGELOG).
///
/// If a future change ever renames or removes an attribute, or makes an optional
/// non-optional, lightweight migration stops being enough and a migration plan becomes
/// mandatory — that is the line to watch.
@available(iOS 17, *)
@Model
final class HabitModel {
    @Attribute(.unique) var id: String
    var title: String
    var habitDescription: String?
    var iconKey: String
    var colorIndex: Int
    var startDate: Date
    /// Added in the second schema revision — optional, so old stores migrate lightly.
    var endDate: Date?
    var templateId: String?
    var coverAnimeSlug: String?
    var createdAt: Date
    var isArchived: Bool
    var reminderEnabled: Bool
    /// Stored as `[Int]` rather than `Set<Int>` — plain arrays of primitives are the safest
    /// SwiftData-supported shape; order carries no meaning here.
    var reminderWeekdays: [Int]
    var reminderHour: Int
    var reminderMinute: Int

    init(from habit: Habit) {
        self.id = habit.id
        self.title = habit.title
        self.habitDescription = habit.description
        self.iconKey = habit.iconKey
        self.colorIndex = habit.colorIndex
        self.startDate = habit.startDate
        self.endDate = habit.endDate
        self.templateId = habit.templateId
        self.coverAnimeSlug = habit.coverAnimeSlug
        self.createdAt = habit.createdAt
        self.isArchived = habit.isArchived
        self.reminderEnabled = habit.reminderEnabled
        self.reminderWeekdays = Array(habit.reminderWeekdays)
        self.reminderHour = habit.reminderHour
        self.reminderMinute = habit.reminderMinute
    }

    /// Writes every field the domain owns, `isArchived` included — mirrors Android, whose
    /// `saveHabit` upserts the whole entity. Callers that edit an existing habit must
    /// therefore carry its current `isArchived` forward (`HabitEditorViewModel` does), or a
    /// plain edit would silently restore an archived habit.
    func apply(_ habit: Habit) {
        self.title = habit.title
        self.habitDescription = habit.description
        self.iconKey = habit.iconKey
        self.colorIndex = habit.colorIndex
        self.startDate = habit.startDate
        self.endDate = habit.endDate
        self.templateId = habit.templateId
        self.coverAnimeSlug = habit.coverAnimeSlug
        self.isArchived = habit.isArchived
        self.reminderEnabled = habit.reminderEnabled
        self.reminderWeekdays = Array(habit.reminderWeekdays)
        self.reminderHour = habit.reminderHour
        self.reminderMinute = habit.reminderMinute
    }

    /// `iconKey` is normalised on the way out: habits created from a template before the fix
    /// were stored with an SF Symbol name (see `HabitIconAliases`).
    func toDomain() -> Habit {
        Habit(
            id: id,
            title: title,
            description: habitDescription,
            iconKey: HabitIconAliases.canonical(iconKey),
            colorIndex: colorIndex,
            startDate: startDate,
            endDate: endDate,
            templateId: templateId,
            coverAnimeSlug: coverAnimeSlug,
            isArchived: isArchived,
            createdAt: createdAt,
            reminderEnabled: reminderEnabled,
            reminderWeekdays: Set(reminderWeekdays),
            reminderHour: reminderHour,
            reminderMinute: reminderMinute
        )
    }
}
