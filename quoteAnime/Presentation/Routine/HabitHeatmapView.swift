import SwiftUI

/// GitHub-style completion heatmap for a single habit. Column-major grid from `HeatmapGrid`;
/// this view owns all masking (future days, days outside the habit's window) since
/// `HeatmapGrid` itself is pure date math with no notion of "today" or habit range.
///
/// Two sizes, one drawing loop:
/// - **compact** (the default, used by `HabitCardView`): flexible width, cells derived from a
///   fixed row height, no labels.
/// - **labeled** (`showLabels: true`, used by `HabitDetailView`): a fixed 10pt cell like
///   Android's `MIN_CELL_DP`, with weekday and month labels, inside a horizontal `ScrollView`
///   so the 26-week range still reaches narrow phones intact instead of being squeezed.
///
/// Unlike Android's, this heatmap is **not** tappable. At 10pt a cell is a quarter of the
/// 44×44pt minimum touch target, so marking lives entirely in `HabitCalendarMonthView`, whose
/// cells are full size. No day becomes unreachable: the calendar navigates months.
struct HabitHeatmapView: View {
    let startDate: Date
    var endDate: Date? = nil
    let completions: Set<Date>
    let accentColor: Color
    var weeks: Int = 17
    var today: Date = Date()
    var showLabels: Bool = false
    var calendar: Calendar = .current

    private let cellSpacing: CGFloat = 3
    private let compactCellSize: CGFloat = 12
    /// Matches Android's `MIN_CELL_DP`.
    private let labeledCellSize: CGFloat = 10
    private let dayLabelWidth: CGFloat = 16
    private let monthLabelHeight: CGFloat = 14

    private var cellSize: CGFloat { showLabels ? labeledCellSize : compactCellSize }
    private var gridHeight: CGFloat {
        CGFloat(HeatmapGrid.rows) * cellSize + CGFloat(HeatmapGrid.rows - 1) * cellSpacing
    }
    private var gridWidth: CGFloat {
        CGFloat(weeks) * cellSize + CGFloat(weeks - 1) * cellSpacing
    }

    var body: some View {
        if showLabels {
            ScrollView(.horizontal, showsIndicators: false) {
                labeledGrid
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mapa de actividad de las últimas \(weeks) semanas")
        } else {
            compactGrid
        }
    }

    // MARK: - Layouts

    private var compactGrid: some View {
        Canvas { context, size in
            let derived = min(
                (size.width - CGFloat(weeks - 1) * cellSpacing) / CGFloat(weeks),
                (size.height - CGFloat(HeatmapGrid.rows - 1) * cellSpacing) / CGFloat(HeatmapGrid.rows)
            )
            draw(in: &context, cellSize: derived)
        }
        .frame(height: gridHeight)
    }

    private var labeledGrid: some View {
        VStack(alignment: .leading, spacing: 4) {
            monthLabels
            HStack(alignment: .top, spacing: 0) {
                dayLabels
                Canvas { context, _ in
                    draw(in: &context, cellSize: cellSize)
                }
                .frame(width: gridWidth, height: gridHeight)
            }
        }
        .padding(.trailing, 2)
    }

    private var dayLabels: some View {
        // Mon / Wed / Fri only, the contribution-graph convention Android also follows —
        // labelling all seven rows is unreadable at this cell size.
        ZStack(alignment: .topLeading) {
            ForEach([0, 2, 4], id: \.self) { row in
                Text(weekdayInitial(row: row))
                    .font(.system(size: 9))
                    .foregroundColor(.textSecondary)
                    .offset(y: CGFloat(row) * (cellSize + cellSpacing) - 1)
            }
        }
        .frame(width: dayLabelWidth, height: gridHeight, alignment: .topLeading)
    }

    private var monthLabels: some View {
        ZStack(alignment: .topLeading) {
            ForEach(monthLabelPositions, id: \.column) { position in
                Text(position.label)
                    .font(.system(size: 9))
                    .foregroundColor(.textSecondary)
                    .offset(x: dayLabelWidth + CGFloat(position.column) * (cellSize + cellSpacing))
            }
        }
        .frame(width: dayLabelWidth + gridWidth, height: monthLabelHeight, alignment: .topLeading)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, cellSize: CGFloat) {
        guard cellSize > 0 else { return }
        let todayStart = calendar.startOfDay(for: today)
        let gridStart = HeatmapGrid.gridStart(today: todayStart, weeks: weeks)

        for column in 0..<weeks {
            for row in 0..<HeatmapGrid.rows {
                let date = HeatmapGrid.date(column: column, row: row, gridStart: gridStart)
                let isFuture = date > todayStart
                let isOutsideRange = !isActive(date)
                let isCompleted = completions.contains(date) && !isFuture && !isOutsideRange

                // Every cell is drawn, even outside the habit's window — same rule as Android's
                // `HabitHeatmap`. Leaving them transparent (what this view used to do) turns the
                // 26-week grid on the detail screen into a lopsided block floating on the right,
                // which reads as a rendering bug rather than as "the habit started in August".
                let color: Color = isCompleted ? accentColor : Color.outline.opacity(0.35)

                let rect = CGRect(
                    x: CGFloat(column) * (cellSize + cellSpacing),
                    y: CGFloat(row) * (cellSize + cellSpacing),
                    width: cellSize,
                    height: cellSize
                )
                context.fill(Path(roundedRect: rect, cornerRadius: cellSize * 0.25), with: .color(color))
            }
        }
    }

    /// Same rule as `Habit.isActiveOn`, expressed on the two dates this view is given rather
    /// than on a whole `Habit` — the compact card only ever knows the start date.
    private func isActive(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard day >= calendar.startOfDay(for: startDate) else { return false }
        guard let endDate else { return true }
        return day <= calendar.startOfDay(for: endDate)
    }

    // MARK: - Labels

    private func weekdayInitial(row: Int) -> String {
        // `veryShortWeekdaySymbols` is Sunday-first; row 0 is Monday.
        let symbols = calendar.veryShortWeekdaySymbols
        return symbols[(row + 1) % 7]
    }

    /// One label per column that contains the 1st of a month — the convention contribution
    /// graphs use, and it keeps every label on the exact column the Canvas draws.
    private var monthLabelPositions: [(column: Int, label: String)] {
        let todayStart = calendar.startOfDay(for: today)
        let gridStart = HeatmapGrid.gridStart(today: todayStart, weeks: weeks)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("MMM")

        return (0..<weeks).compactMap { column in
            let firstOfMonth = (0..<HeatmapGrid.rows)
                .map { HeatmapGrid.date(column: column, row: $0, gridStart: gridStart) }
                .first { calendar.component(.day, from: $0) == 1 }
            guard let firstOfMonth else { return nil }
            return (column, formatter.string(from: firstOfMonth))
        }
    }
}

#Preview("Heatmap compacto") {
    let today = Date()
    let calendar = Calendar.current
    let completions = Set(
        (0..<90).filter { $0 % 3 != 0 }.compactMap {
            calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: today))
        }
    )
    return HabitHeatmapView(
        startDate: calendar.date(byAdding: .month, value: -3, to: today)!,
        completions: completions,
        accentColor: HabitPalette.color(at: 0)
    )
    .padding()
    .background(Color.bgDark)
}

#Preview("Heatmap con etiquetas") {
    let today = Date()
    let calendar = Calendar.current
    let completions = Set(
        (0..<170).filter { $0 % 3 != 0 }.compactMap {
            calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: today))
        }
    )
    return HabitHeatmapView(
        startDate: calendar.date(byAdding: .month, value: -6, to: today)!,
        completions: completions,
        accentColor: HabitPalette.color(at: 3),
        weeks: 26,
        showLabels: true
    )
    .padding()
    .background(Color.bgDark)
}
