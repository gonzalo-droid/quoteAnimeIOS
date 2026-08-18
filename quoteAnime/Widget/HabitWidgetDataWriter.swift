import Foundation
import WidgetKit

enum HabitWidgetSharedKeys {
    static let snapshot = "habit_widget_snapshot"
}

/// Mirrors the shape `RoutineSummaryWidget` (in the widget extension target) decodes —
/// duplicated there rather than shared, since a WidgetKit extension can't import the app
/// target's Domain types (see `QuoteAnimeWidget.swift`'s own note on this).
struct HabitWidgetSnapshotItem: Codable {
    let id: String
    let title: String
    let colorIndex: Int
    let currentStreak: Int
    let completedToday: Bool
}

struct HabitWidgetSnapshot: Codable {
    let habits: [HabitWidgetSnapshotItem]
    let globalStreak: Int
}

/// Writes the active-habits summary to the shared App Group so `RoutineSummaryWidget` can
/// render without touching SwiftData directly. Call whenever `RoutineViewModel` reloads —
/// habit data has no network fallback the way quotes do, so this is the widget's only source.
enum HabitWidgetDataWriter {
    static func write(habits: [HabitWithProgress], globalStreak: Int) {
        guard let defaults = UserDefaults(suiteName: WidgetSharedKeys.suiteName) else { return }
        let snapshot = HabitWidgetSnapshot(
            habits: habits.map {
                HabitWidgetSnapshotItem(
                    id: $0.habit.id,
                    title: $0.habit.title,
                    colorIndex: $0.habit.colorIndex,
                    currentStreak: $0.streak.current,
                    completedToday: $0.streak.completedToday
                )
            },
            globalStreak: globalStreak
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: HabitWidgetSharedKeys.snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "RoutineSummaryWidget")
    }
}
