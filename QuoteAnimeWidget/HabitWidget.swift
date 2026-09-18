import WidgetKit
import SwiftUI
import AppIntents

/// One widget instance follows one habit, chosen by the user — Android's `HabitWidget` plus its
/// `HabitWidgetConfigureActivity`.
///
/// Android has to ship that Activity because an app widget's only way to be configured is to
/// launch one (`android:configure`) the moment it lands on the home screen. iOS already has the
/// affordance: `AppIntentConfiguration` turns the `@Parameter` below into a native row in the
/// widget's own edit sheet, with a picker fed by `HabitOptionsProvider`. So the port is a
/// configuration intent, not a screen — there is nothing here to build a UI for.
///
/// **iOS 17+.** `AppIntentConfiguration` does not exist on iOS 16, which the app and the rest of
/// the extension still support; the `@available` lives on the `WidgetBundle` member so the other
/// widgets keep working on 16.6. "Mi Rutina" is itself iOS 17+ (SwiftData), so no one loses a
/// widget they could have used.
///
/// The extension cannot open the app's SwiftData store, so both the picker and the heatmap read the
/// App Group snapshot `RoutineWidgetRefresher` writes — see `WidgetSharedModel.swift`.

// MARK: - Configuration intent

/// Fills the picker in the widget's edit sheet: one row per active habit, with its name and its
/// glyph — the same list Android's `HabitWidgetConfigureActivity` shows. Reads the App Group
/// snapshot, the only habit data an extension can reach, so the list is empty until the app has run
/// once (Android's screen is likewise empty until a habit exists).
///
/// Only **active** habits are offered, exactly like Android (`repository.getActiveHabits()`). A
/// habit that is archived later keeps rendering, because the widget stores its id and looks it up
/// in the whole snapshot, not in this list.
@available(iOS 17.0, *)
struct HabitOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> ItemCollection<String> {
        let habits = HabitWidgetSnapshot.read()?.activeHabits ?? []
        return ItemCollection {
            ItemSection(items: habits.map { habit in
                IntentItem<String>(
                    habit.id,
                    // The habit's title is the user's own words — `stringLiteral` uses the text
                    // as-is instead of looking it up, the `Text(verbatim:)` of this API.
                    title: LocalizedStringResource(stringLiteral: habit.title),
                    image: .init(systemName: habit.symbol)
                )
            })
        }
    }
}

/// The widget stores the habit's **id**, not an `AppEntity`.
///
/// An `AppEntity` + `EntityQuery` is the richer way to model this, and it was the first attempt —
/// but the entity has to survive a round trip through the stored configuration, and it did not:
/// the edit sheet showed the chosen habit while the extension's timeline provider received `nil`
/// and `entities(for:)` was never called, so every widget rendered the wrong habit (or the prompt).
/// A `String` cannot fail to resolve, and `DynamicOptionsProvider` gives the same native picker,
/// titles and icons included. Nothing about the feature is lost.
@available(iOS 17.0, *)
struct SelectHabitIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Elige un hábito" }
    static var description: IntentDescription {
        IntentDescription("Sigue el progreso de un hábito desde la pantalla de inicio")
    }

    @Parameter(title: "Hábito", optionsProvider: HabitOptionsProvider())
    var habitId: String?

    init() {}
}

// MARK: - Entry

@available(iOS 17.0, *)
struct HabitWidgetEntry: TimelineEntry {
    enum Content {
        /// No habit picked yet (nothing in the snapshot when the widget was added).
        case unconfigured
        /// A habit was picked and has since been deleted — Android's `habit_widget_deleted`.
        case missing
        case habit(HabitWidgetSnapshotItem)
    }

    let date: Date
    let content: Content

    static let placeholder = HabitWidgetEntry(
        date: .now,
        content: .habit(
            HabitWidgetSnapshotItem(
                id: "preview",
                title: "Meditar",
                colorIndex: 0,
                currentStreak: 12,
                completedToday: true,
                symbolName: "figure.mind.and.body",
                isArchived: false,
                completions: HabitWidgetEntry.sampleDays
            )
        )
    )

    /// Two out of every three days of the last nine weeks — enough for the gallery preview to read
    /// as a heatmap rather than as an empty grid.
    static let sampleDays: [String] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<(HabitWidgetSnapshot.heatmapWeeks * 7))
            .filter { $0 % 3 != 0 }
            .compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            .map { HabitWidgetDay.key($0, calendar: calendar) }
    }()
}

// MARK: - Provider

@available(iOS 17.0, *)
struct HabitWidgetProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> HabitWidgetEntry { .placeholder }

    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> HabitWidgetEntry {
        context.isPreview ? .placeholder : entry(for: configuration)
    }

    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<HabitWidgetEntry> {
        let entry = entry(for: configuration)
        // Marking a habit in the app already forces a reload through `RoutineWidgetRefresher`, so
        // the only change this has to wake up for is the day itself rolling over: the heatmap grows
        // a cell and a streak can go stale. Android leans on a 24h `PeriodicWorkRequest` for the
        // same reason; here the next midnight is both cheaper and exact.
        let calendar = Calendar.current
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: entry.date))
            ?? entry.date.addingTimeInterval(3600 * 6)
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }

    private func entry(for configuration: SelectHabitIntent) -> HabitWidgetEntry {
        guard let habitId = configuration.habitId, !habitId.isEmpty else {
            return HabitWidgetEntry(date: .now, content: .unconfigured)
        }
        // Looked up in the whole snapshot, archived habits included: a widget bound to a habit the
        // user later archives keeps drawing its history, as Android's worker does. Only a real
        // delete takes it out of the snapshot, and that is what `.missing` is for.
        guard let item = HabitWidgetSnapshot.read()?.habit(id: habitId) else {
            return HabitWidgetEntry(date: .now, content: .missing)
        }
        return HabitWidgetEntry(date: .now, content: .habit(item))
    }
}

// MARK: - Heatmap
// The app draws this with a `Canvas` in `HabitHeatmapView`; that view belongs to the app target, so
// the drawing loop is reproduced here for the same reason the palette is — see `WidgetSharedModel`.
// This copy is deliberately the simpler one: no labels, no habit window, no tap targets.

@available(iOS 17.0, *)
struct HabitWidgetHeatmap: View {
    let completedDays: Set<String>
    let accentColor: Color
    var weeks: Int = HabitWidgetSnapshot.heatmapWeeks
    var today: Date = .now

    private let spacing: CGFloat = 2.5

    var body: some View {
        Canvas { context, size in
            let cell = min(
                (size.width - CGFloat(weeks - 1) * spacing) / CGFloat(weeks),
                (size.height - CGFloat(WidgetHeatmapGrid.rows - 1) * spacing) / CGFloat(WidgetHeatmapGrid.rows)
            )
            guard cell > 0 else { return }

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: today)
            let gridStart = WidgetHeatmapGrid.gridStart(today: todayStart, weeks: weeks)

            for column in 0..<weeks {
                for row in 0..<WidgetHeatmapGrid.rows {
                    let date = WidgetHeatmapGrid.date(column: column, row: row, gridStart: gridStart)
                    let isFuture = date > todayStart
                    let isCompleted = !isFuture && completedDays.contains(HabitWidgetDay.key(date, calendar: calendar))
                    // Every cell is drawn, future ones included but dimmer — an empty tail would
                    // read as a clipped grid rather than as "the week isn't over yet".
                    let color = isCompleted
                        ? accentColor
                        : Color.white.opacity(isFuture ? 0.04 : 0.10)

                    let rect = CGRect(
                        x: CGFloat(column) * (cell + spacing),
                        y: CGFloat(row) * (cell + spacing),
                        width: cell,
                        height: cell
                    )
                    context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.25), with: .color(color))
                }
            }
        }
    }
}

// MARK: - View

@available(iOS 17.0, *)
struct HabitWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitWidgetEntry

    var body: some View {
        switch entry.content {
        case .unconfigured:
            message("Mantén pulsado el widget para elegir un hábito.")
        case .missing:
            message("Este hábito ya no existe.")
        case .habit(let habit):
            habitBody(habit)
        }
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.wTextSecond)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
    }

    @ViewBuilder
    private func habitBody(_ habit: HabitWidgetSnapshotItem) -> some View {
        if family == .systemMedium {
            // Medium is wide, not tall: side by side keeps the cells big instead of stretching
            // nine columns across the whole width.
            HStack(alignment: .top, spacing: 14) {
                header(habit)
                    .frame(maxWidth: .infinity, alignment: .leading)
                heatmap(habit)
                    .frame(width: 150)
            }
            .padding(14)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                header(habit)
                heatmap(habit)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(14)
        }
    }

    private func header(_ habit: HabitWidgetSnapshotItem) -> some View {
        let color = habitColor(at: habit.colorIndex)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: habit.symbol)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                // The habit's title is the user's own text — never translated.
                Text(verbatim: habit.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.wTextPrimary)
                    .lineLimit(1)
                    // A name like "Find the One Piece" is cut to "Find the O…" on the small size
                    // next to the icon; shrinking a little buys the whole title back without
                    // letting a very long one take over the widget.
                    .minimumScaleFactor(0.75)
            }
            HStack(spacing: 4) {
                Text("\(habit.currentStreak) días")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color)
                if habit.completedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(color)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(habit.currentStreak) días seguidos")
        }
    }

    private func heatmap(_ habit: HabitWidgetSnapshotItem) -> some View {
        HabitWidgetHeatmap(
            completedDays: habit.completionDays,
            accentColor: habitColor(at: habit.colorIndex)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mapa de actividad de las últimas \(HabitWidgetSnapshot.heatmapWeeks) semanas")
    }
}

// MARK: - Widget

@available(iOS 17.0, *)
struct HabitWidget: Widget {
    let kind = "HabitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectHabitIntent.self, provider: HabitWidgetProvider()) { entry in
            HabitWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { Color.wBgDark }
                // Android's `HabitWidget` opens Mi Rutina (the list, not the habit) on any tap.
                .widgetURL(WidgetDeepLink.routine)
        }
        .configurationDisplayName("Hábito")
        .description("Sigue el progreso de un hábito desde la pantalla de inicio")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview("Small", as: .systemSmall) {
    HabitWidget()
} timeline: {
    HabitWidgetEntry.placeholder
}

@available(iOS 17.0, *)
#Preview("Medium", as: .systemMedium) {
    HabitWidget()
} timeline: {
    HabitWidgetEntry.placeholder
}

@available(iOS 17.0, *)
#Preview("Sin elegir", as: .systemSmall) {
    HabitWidget()
} timeline: {
    HabitWidgetEntry(date: .now, content: .unconfigured)
}

@available(iOS 17.0, *)
#Preview("Hábito borrado", as: .systemSmall) {
    HabitWidget()
} timeline: {
    HabitWidgetEntry(date: .now, content: .missing)
}
