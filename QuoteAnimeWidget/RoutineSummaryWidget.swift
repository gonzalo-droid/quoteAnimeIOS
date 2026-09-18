import WidgetKit
import SwiftUI

// Snapshot shape, palette and App Group keys live in `WidgetSharedModel.swift` — all
// hand-kept copies of app-target code, since a widget extension can't import the app target.

// MARK: - Entry

struct RoutineSummaryEntry: TimelineEntry {
    let date: Date
    let habits: [HabitWidgetSnapshotItem]
    let globalStreak: Int

    static let placeholder = RoutineSummaryEntry(
        date: .now,
        habits: [
            HabitWidgetSnapshotItem(id: "1", title: "Meditar", colorIndex: 0, currentStreak: 5,
                                    completedToday: true, symbolName: "figure.mind.and.body",
                                    isArchived: false, completions: nil),
            HabitWidgetSnapshotItem(id: "2", title: "Leer", colorIndex: 2, currentStreak: 2,
                                    completedToday: false, symbolName: "book.fill",
                                    isArchived: false, completions: nil),
            HabitWidgetSnapshotItem(id: "3", title: "Entrenar", colorIndex: 10, currentStreak: 12,
                                    completedToday: true, symbolName: "dumbbell.fill",
                                    isArchived: false, completions: nil)
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
        guard let snapshot = HabitWidgetSnapshot.read() else { return .empty }
        // `activeHabits`, not `habits`: since the per-habit widget shipped, the snapshot also
        // carries archived habits so a widget bound to one keeps rendering. This summary is about
        // what the user is keeping up with today, so archived ones stay out of it.
        return RoutineSummaryEntry(date: .now, habits: snapshot.activeHabits, globalStreak: snapshot.globalStreak)
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
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.wTextPrimary)
                Spacer()
                if entry.globalStreak > 0 {
                    Label {
                        Text(verbatim: "\(entry.globalStreak)")
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.wAccentPurple)
                    .accessibilityLabel("\(entry.globalStreak) días seguidos")
                }
            }

            if entry.habits.isEmpty {
                Spacer()
                Text("Sin hábitos activos")
                    .font(.caption)
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
                                .font(.caption)
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
        .dynamicTypeSize(...wMaxDynamicTypeSize)
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
                    .widgetURL(WidgetDeepLink.routine)
            } else {
                // On iOS 16 the app has no Mi Rutina: the router ignores the link and the tap
                // just opens the app.
                ZStack {
                    Color.wBgDark
                    RoutineSummaryWidgetEntryView(entry: entry)
                }
                .widgetURL(WidgetDeepLink.routine)
            }
        }
        .configurationDisplayName("Mi Rutina")
        .description("Tus hábitos activos, con racha y check de hoy.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview("Small", as: .systemSmall) {
    RoutineSummaryWidget()
} timeline: {
    RoutineSummaryEntry.placeholder
}

@available(iOS 17.0, *)
#Preview("Medium", as: .systemMedium) {
    RoutineSummaryWidget()
} timeline: {
    RoutineSummaryEntry.placeholder
}

@available(iOS 17.0, *)
#Preview("Empty", as: .systemMedium) {
    RoutineSummaryWidget()
} timeline: {
    RoutineSummaryEntry.empty
}
