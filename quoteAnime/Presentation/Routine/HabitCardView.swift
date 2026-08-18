import SwiftUI

/// Tapping the card opens the editor (no detail screen in this phase — see RoutineView).
/// Trailing controls consume their own tap first so they never also open the editor.
struct HabitCardView: View {
    let item: HabitWithProgress
    var isArchived: Bool = false
    let onToggleToday: () -> Void
    let onTap: () -> Void
    var onArchive: () -> Void = {}
    var onUnarchive: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var showDeleteConfirm = false

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

                    trailingControls
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
        .confirmationDialog(
            "Eliminar “\(item.habit.title)”",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive, action: onDelete)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borra el hábito y todo su historial. Esta acción no se puede deshacer.")
        }
    }

    @ViewBuilder
    private var trailingControls: some View {
        if isArchived {
            Button(action: onUnarchive) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.textSecondary)
            }
            .buttonStyle(.plain)

            Button { showDeleteConfirm = true } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(.heartRed)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onToggleToday) {
                Image(systemName: item.streak.completedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundColor(item.streak.completedToday ? accentColor : .textSecondary)
            }
            .buttonStyle(.plain)

            Menu {
                Button("Archivar", systemImage: "archivebox", action: onArchive)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 28)
            }
        }
    }
}
