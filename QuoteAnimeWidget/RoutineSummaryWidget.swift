import WidgetKit
import SwiftUI

// MARK: - Shared snapshot shape
// Duplicated from `HabitWidgetDataWriter.swift` (app target) — a widget extension can't
// import the app target's types, same reason `QuoteAnimeWidget.swift` redeclares its own theme.

private let kAppGroupSuite = "group.com.gonzadev.quoteAnime"
private let kSnapshotKey = "habit_widget_snapshot"

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

// MARK: - Palette (14 colors, same order/index as HabitPalette.swift in the app target)

private let habitPaletteColors: [Color] = [
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

private func habitColor(at index: Int) -> Color {
    let count = habitPaletteColors.count
    return habitPaletteColors[((index % count) + count) % count]
}

// MARK: - Entry

struct RoutineSummaryEntry: TimelineEntry {
    let date: Date
    let habits: [HabitWidgetSnapshotItem]
    let globalStreak: Int

    static let placeholder = RoutineSummaryEntry(
        date: .now,
        habits: [
            HabitWidgetSnapshotItem(id: "1", title: "Meditar", colorIndex: 0, currentStreak: 5, completedToday: true),
            HabitWidgetSnapshotItem(id: "2", title: "Leer", colorIndex: 2, currentStreak: 2, completedToday: false),
            HabitWidgetSnapshotItem(id: "3", title: "Entrenar", colorIndex: 10, currentStreak: 12, completedToday: true)
        ],
        globalStreak: 5
    )

    static let empty = RoutineSummaryEntry(date: .now, habits: [], globalStreak: 0)
}

// MARK: - Provider

struct RoutineSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> RoutineSummaryEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (RoutineSummaryEntry) -> Void) {
        completion(context.isPreview ? .placeholder : readSnapshot())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RoutineSummaryEntry>) -> Void) {
        let entry = readSnapshot()
        // Habit data has no network fallback — this is just a safety refresh in case the app
        // never re-runs `HabitWidgetDataWriter.write` (e.g. "completedToday" crossing midnight).
        let next = Calendar.current.date(byAdding: .hour, value: 3, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readSnapshot() -> RoutineSummaryEntry {
        guard
            let defaults = UserDefaults(suiteName: kAppGroupSuite),
            let data = defaults.data(forKey: kSnapshotKey),
            let snapshot = try? JSONDecoder().decode(HabitWidgetSnapshot.self, from: data)
        else {
            return .empty
        }
        return RoutineSummaryEntry(date: .now, habits: snapshot.habits, globalStreak: snapshot.globalStreak)
    }
}

// MARK: - View

struct RoutineSummaryWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RoutineSummaryEntry

    private var maxRows: Int {
        family == .systemLarge ? 6 : 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mi Rutina")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.wTextPrimary)
                Spacer()
                if entry.globalStreak > 0 {
                    Label("\(entry.globalStreak)", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.wAccentPurple)
                }
            }

            if entry.habits.isEmpty {
                Spacer()
                Text("Sin hábitos activos")
                    .font(.system(size: 12))
                    .foregroundColor(.wTextSecond)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(entry.habits.prefix(maxRows), id: \.id) { habit in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(habitColor(at: habit.colorIndex))
                                .frame(width: 8, height: 8)
                            Text(habit.title)
                                .font(.system(size: 12))
                                .foregroundColor(.wTextPrimary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: habit.completedToday ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundColor(habit.completedToday ? habitColor(at: habit.colorIndex) : .wTextSecond)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Widget

struct RoutineSummaryWidget: Widget {
    let kind = "RoutineSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RoutineSummaryProvider()) { entry in
            if #available(iOS 17.0, *) {
                RoutineSummaryWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) { Color.wBgDark }
            } else {
                ZStack {
                    Color.wBgDark
                    RoutineSummaryWidgetEntryView(entry: entry)
                }
            }
        }
        .configurationDisplayName("Mi Rutina")
        .description("Tus hábitos activos, con racha y check de hoy.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    RoutineSummaryWidget()
} timeline: {
    RoutineSummaryEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    RoutineSummaryWidget()
} timeline: {
    RoutineSummaryEntry.placeholder
}

#Preview("Empty", as: .systemMedium) {
    RoutineSummaryWidget()
} timeline: {
    RoutineSummaryEntry.empty
}
