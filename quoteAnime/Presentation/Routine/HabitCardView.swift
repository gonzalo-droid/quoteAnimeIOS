import SwiftUI

/// Tapping the card opens the editor (no detail screen in this phase — see RoutineView).
/// The check button consumes its own tap first so it never also opens the editor.
struct HabitCardView: View {
    let item: HabitWithProgress
    let onToggleToday: () -> Void
    let onTap: () -> Void

    private var accentColor: Color { HabitPalette.color(at: item.habit.colorIndex) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: HabitIcons.symbol(for: item.habit.iconKey))
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                        .frame(width: 32, height: 32)

                    Text(item.habit.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Button(action: onToggleToday) {
                        Image(systemName: item.streak.completedToday ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 26))
                            .foregroundColor(item.streak.completedToday ? accentColor : .textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                HabitHeatmapView(
                    startDate: item.habit.startDate,
                    completions: item.completions,
                    accentColor: accentColor
                )

                HStack {
                    Label("\(item.streak.current)", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("Mejor: \(item.streak.best)")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(14)
            .background(Color.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(accentColor.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
