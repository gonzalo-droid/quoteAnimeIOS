import SwiftUI

// Everything in this file is a deliberate, hand-kept copy of app-target code: a WidgetKit
// extension is its own binary and cannot import the app target's types. Each block names the file
// it mirrors — **change both sides together**.

// MARK: - App Group

let kAppGroupSuite = "group.com.gonzadev.quoteAnime"

/// Mirrors `WidgetSharedKeys` / `HabitWidgetSharedKeys` / `UserPreferencesStore.Keys`.
enum WidgetSharedKey {
    static let quoteText          = "widget_quote_text"
    static let quoteAuthor        = "widget_quote_author"
    static let quoteAnime         = "widget_quote_anime"
    static let imageUrl           = "widget_image_url"
    static let updateTimesPerDay  = "widget_update_times_per_day"
    static let habitSnapshot      = "habit_widget_snapshot"
    /// The anime selection, mirrored into the App Group by `UserPreferencesStore`. Empty or
    /// absent means "all animes", exactly as in the app and on Android.
    static let selectedCategoryIds = "pref_selected_category_ids"
}

// MARK: - Deep link
// Mirrors `AppDeepLink.url` (`quoteAnime/Presentation/Navigation/AppDeepLink.swift`); the scheme
// is registered under `CFBundleURLTypes` in the app's `Info.plist`. `AppDeepLinkTests` reads this
// file and fails if the two stop agreeing.

/// Where a tap on a routine widget opens the app: Mi Rutina, as Android's `EXTRA_OPEN_ROUTINE`.
enum WidgetDeepLink {
    static let routine = URL(string: "quoteanime://routine")!
}

// MARK: - Habit snapshot
// Mirrors `HabitWidgetDataWriter.swift`. Fields added after the first version are optional so a
// snapshot written by an older build still decodes instead of blanking the widget.

struct HabitWidgetSnapshotItem: Codable {
    let id: String
    let title: String
    let colorIndex: Int
    let currentStreak: Int
    let completedToday: Bool
    let symbolName: String?
    let isArchived: Bool?
    let completions: [String]?

    var archived: Bool { isArchived ?? false }
    /// Older snapshots carry no glyph; fall back to the same generic one the app uses.
    var symbol: String { symbolName ?? "checkmark.circle.fill" }
    var completionDays: Set<String> { Set(completions ?? []) }
}

struct HabitWidgetSnapshot: Codable {
    let habits: [HabitWidgetSnapshotItem]
    let globalStreak: Int

    static let heatmapWeeks = 9

    static func read() -> HabitWidgetSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: kAppGroupSuite),
            let data = defaults.data(forKey: WidgetSharedKey.habitSnapshot),
            let snapshot = try? JSONDecoder().decode(HabitWidgetSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    /// What the summary widget lists and what the habit picker offers: the habits the user is
    /// actually keeping. Archived ones stay in the snapshot only so a widget already bound to one
    /// keeps rendering its history.
    var activeHabits: [HabitWidgetSnapshotItem] { habits.filter { !$0.archived } }

    func habit(id: String) -> HabitWidgetSnapshotItem? { habits.first { $0.id == id } }
}

/// Mirrors `HabitWidgetDay` — days travel as `yyyy-MM-dd` text, never as `Date`, so the two sides
/// never disagree about which day an instant belongs to.
enum HabitWidgetDay {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

// MARK: - Heatmap grid
// Mirrors `HeatmapGrid.swift`: column-major, weeks always start Monday, masking is the caller's job.

enum WidgetHeatmapGrid {
    static let rows = 7

    static func gridStart(today: Date, weeks: Int) -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2 // Monday

        let anchor = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: today) ?? today
        let weekday = calendar.component(.weekday, from: anchor)
        let daysSinceMonday = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: calendar.startOfDay(for: anchor)) ?? anchor
    }

    static func date(column: Int, row: Int, gridStart: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: column * rows + row, to: gridStart) ?? gridStart
    }
}

// MARK: - Palette
// Mirrors `HabitPalette.swift` — 14 colors, persisted by index. Never reorder.

let habitPaletteColors: [Color] = [
    Color(red: 0.655, green: 0.545, blue: 0.980), // 0 purple
    Color(red: 1.000, green: 0.420, blue: 0.541), // 1 rose
    Color(red: 0.290, green: 0.871, blue: 0.502), // 2 green
    Color(red: 0.220, green: 0.741, blue: 0.973), // 3 sky
    Color(red: 0.984, green: 0.749, blue: 0.141), // 4 amber
    Color(red: 0.984, green: 0.447, blue: 0.522), // 5 coral
    Color(red: 0.176, green: 0.831, blue: 0.749), // 6 teal
    Color(red: 0.910, green: 0.475, blue: 0.980), // 7 fuchsia
    Color(red: 0.510, green: 0.549, blue: 0.976), // 8 indigo
    Color(red: 0.639, green: 0.902, blue: 0.208), // 9 lime
    Color(red: 0.984, green: 0.573, blue: 0.235), // 10 orange
    Color(red: 0.973, green: 0.443, blue: 0.443), // 11 red
    Color(red: 0.404, green: 0.910, blue: 0.976), // 12 cyan
    Color(red: 0.957, green: 0.447, blue: 0.714)  // 13 pink
]

func habitColor(at index: Int) -> Color {
    let count = habitPaletteColors.count
    return habitPaletteColors[((index % count) + count) % count]
}
