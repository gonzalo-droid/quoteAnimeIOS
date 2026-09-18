import SwiftUI

/// Tapping the card opens the habit detail, same as Android; editing moved into the card's
/// overflow menu (and the detail's toolbar menu) so the primary tap goes to the richer screen.
/// Trailing controls consume their own tap first so they never also open the detail.
struct HabitCardView: View {
    let item: HabitWithProgress
    var isArchived: Bool = false
    let onToggleToday: () -> Void
    let onTap: () -> Void
    var onEdit: () -> Void = {}
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
                        // Decorative next to the title, as on Android (`contentDescription = null`).
                        .accessibilityHidden(true)

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
                    Label {
                        Text(verbatim: "\(item.streak.current)")
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .accessibilityLabel("\(item.streak.current) días seguidos")
                    Spacer()
                    Text("Mejor: \(item.streak.best)")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(14)
            .background(cardBackground)
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

    /// A habit created from a themed suggestion shows its cover behind the card, scrimmed to 82 %
    /// of the card's own colour so the text and the heatmap stay legible — Android's `HabitCard`
    /// (`923e552`). Everyone else gets the plain surface.
    @ViewBuilder
    private var cardBackground: some View {
        if let asset = HabitThemeImages.assetName(for: item.habit.coverAnimeSlug) {
            Color.surface
                .overlay(Image(asset).resizable().scaledToFill())
                .overlay(Color.surface.opacity(0.82))
                .clipped()
                // The cropped overflow still hit-tests; without this it steals taps from the
                // neighbouring cards (see `ThemedSuggestionPreview`).
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            Color.surface
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
            .accessibilityLabel("Restaurar")

            Button { showDeleteConfirm = true } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(.heartRed)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Eliminar")
        } else {
            Button(action: onToggleToday) {
                Image(systemName: item.streak.completedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundColor(item.streak.completedToday ? accentColor : .textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.streak.completedToday ? "Desmarcar hoy" : "Marcar hoy")

            Menu {
                Button("Editar", systemImage: "pencil", action: onEdit)
                Button("Archivar", systemImage: "archivebox", action: onArchive)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Acciones de \(item.habit.title)")
        }
    }
}
