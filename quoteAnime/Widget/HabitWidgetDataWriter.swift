import Foundation
import WidgetKit

enum HabitWidgetSharedKeys {
    static let snapshot = "habit_widget_snapshot"
}

/// A day, as the snapshot writes it: `yyyy-MM-dd`, the same text Android's `LocalDate.toString()`
/// produces and the same thing `HabitWidgetState.encodeCompletions` stores there.
///
/// Days travel as strings rather than as `Date`s on purpose. The extension renders the heatmap
/// hours or days after the app wrote the snapshot, and a `Date` would have to be turned back into
/// "which day is this" on the other side — a round trip that silently shifts by one whenever the
/// two sides disagree about the timezone. A day key is already the answer, so both sides only ever
/// compare text.
enum HabitWidgetDay {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// Mirrors the shape `RoutineSummaryWidget` and `HabitWidget` (in the widget extension target)
/// decode — duplicated there rather than shared, since a WidgetKit extension can't import the app
/// target's Domain types (see `QuoteAnimeWidget.swift`'s own note on this). **Change both sides
/// together.**
///
/// Everything added after the first version is optional so that a snapshot written by an older
/// build still decodes: a user who updates the app while a summary widget sits on their home
/// screen keeps seeing it until the app runs once and rewrites the snapshot.
struct HabitWidgetSnapshotItem: Codable {
    let id: String
    let title: String
    let colorIndex: Int
    let currentStreak: Int
    let completedToday: Bool
    /// v2. The SF Symbol name, already resolved through `HabitIcons` (aliases included). The
    /// glyph is resolved here rather than in the extension so the icon table doesn't have to be
    /// duplicated across the target boundary too.
    let symbolName: String?
    /// v2. Archived habits are in the snapshot so a widget already bound to one keeps rendering
    /// its history, exactly as Android's `UpdateHabitWidgetWorker` does (it looks the habit up by
    /// id, which returns archived habits too). The summary widget filters them out.
    let isArchived: Bool?
    /// v2. Day keys of the last `HabitWidgetSnapshot.heatmapWeeks` weeks — the heatmap's window,
    /// not the habit's whole history.
    let completions: [String]?

    var archived: Bool { isArchived ?? false }
    var completionDays: Set<String> { Set(completions ?? []) }
}

struct HabitWidgetSnapshot: Codable {
    /// Both active and archived habits (`isArchived` tells them apart).
    let habits: [HabitWidgetSnapshotItem]
    let globalStreak: Int

    /// Fewer weeks than the in-app heatmap (17 on the card, 26 on the detail) — a widget has far
    /// less room. Same number Android's `HabitWidget` uses, so both platforms show the same span.
    static let heatmapWeeks = 9

    // The two lookups below are the contract the extension's `HabitEntityQuery` and
    // `RoutineSummaryProvider` implement, mirrored here so they can be pinned by tests — the test
    // target can't import the widget extension. They have no caller inside the app on purpose;
    // if the rule changes, it changes in both copies. Same arrangement as `HabitPalette`, in the
    // other direction.

    /// What the habit picker offers and what the summary widget lists: habits the user is still
    /// keeping. Archived ones stay in the snapshot only so a widget already bound to one keeps
    /// rendering its history.
    var activeHabits: [HabitWidgetSnapshotItem] { habits.filter { !$0.archived } }

    /// Resolution by id, archived included — a widget bound to a habit that was later archived must
    /// keep working. `nil` for a habit that was deleted, which is what puts the widget into its
    /// "this habit no longer exists" state.
    func habit(id: String) -> HabitWidgetSnapshotItem? { habits.first { $0.id == id } }
}

/// Writes the habit snapshot to the shared App Group so the widget extension can render without
/// touching SwiftData directly — the extension has no access to the app's store, so this is the
/// widgets' only source of truth (habits have no network fallback the way quotes do).
///
/// Don't call this directly from a view model: `RoutineWidgetRefresher` is the single entry point,
/// the way Android funnels every refresh through `RoutineWidgetScheduler`.
enum HabitWidgetDataWriter {

    static func write(_ snapshot: HabitWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: WidgetSharedKeys.suiteName) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: HabitWidgetSharedKeys.snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "RoutineSummaryWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitWidget")
    }

    /// Pure — no I/O — so the trimming and the day encoding can be tested without an App Group.
    static func snapshot(
        active: [HabitWithProgress],
        archived: [HabitWithProgress] = [],
        globalStreak: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> HabitWidgetSnapshot {
        let windowStart = calendar.date(
            byAdding: .weekOfYear,
            value: -HabitWidgetSnapshot.heatmapWeeks,
            to: calendar.startOfDay(for: today)
        ) ?? calendar.startOfDay(for: today)

        func item(_ entry: HabitWithProgress, archived: Bool) -> HabitWidgetSnapshotItem {
            let visible = entry.completions
                .filter { calendar.startOfDay(for: $0) >= windowStart }
                .map { HabitWidgetDay.key($0, calendar: calendar) }
            return HabitWidgetSnapshotItem(
                id: entry.habit.id,
                title: entry.habit.title,
                colorIndex: entry.habit.colorIndex,
                currentStreak: entry.streak.current,
                completedToday: entry.streak.completedToday,
                symbolName: HabitIcons.symbol(for: entry.habit.iconKey),
                isArchived: archived,
                completions: visible.sorted()
            )
        }

        return HabitWidgetSnapshot(
            habits: active.map { item($0, archived: false) } + archived.map { item($0, archived: true) },
            globalStreak: globalStreak
        )
    }
}
