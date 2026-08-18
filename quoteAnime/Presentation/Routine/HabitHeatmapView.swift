import SwiftUI

/// Compact GitHub-style completion heatmap for a single habit. Column-major grid from
/// `HeatmapGrid`; this view owns all masking (future days, days before the habit started)
/// since `HeatmapGrid` itself is pure date math with no notion of "today" or habit range.
struct HabitHeatmapView: View {
    let startDate: Date
    let completions: Set<Date>
    let accentColor: Color
    var weeks: Int = 17
    var today: Date = Date()

    private let cellSpacing: CGFloat = 3

    var body: some View {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let startDay = calendar.startOfDay(for: startDate)
        let gridStart = HeatmapGrid.gridStart(today: todayStart, weeks: weeks)

        Canvas { context, size in
            let cellSize = min(
                (size.width - CGFloat(weeks - 1) * cellSpacing) / CGFloat(weeks),
                (size.height - CGFloat(HeatmapGrid.rows - 1) * cellSpacing) / CGFloat(HeatmapGrid.rows)
            )
            guard cellSize > 0 else { return }

            for column in 0..<weeks {
                for row in 0..<HeatmapGrid.rows {
                    let date = HeatmapGrid.date(column: column, row: row, gridStart: gridStart)
                    let isFuture = date > todayStart
                    let isOutsideRange = date < startDay
                    let isCompleted = completions.contains(date) && !isFuture && !isOutsideRange

                    let color: Color = isCompleted
                        ? accentColor
                        : (isFuture || isOutsideRange ? Color.clear : Color.outline.opacity(0.35))

                    let rect = CGRect(
                        x: CGFloat(column) * (cellSize + cellSpacing),
                        y: CGFloat(row) * (cellSize + cellSpacing),
                        width: cellSize,
                        height: cellSize
                    )
                    let path = Path(roundedRect: rect, cornerRadius: cellSize * 0.25)
                    context.fill(path, with: .color(color))
                }
            }
        }
        .frame(height: CGFloat(HeatmapGrid.rows) * 12 + CGFloat(HeatmapGrid.rows - 1) * cellSpacing)
    }
}
