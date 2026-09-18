import SwiftUI

/// The card that shows a themed suggestion with its cover — Android's `ThemedSuggestionPreview`
/// (`HabitEditorSheet.kt`), used by the editor and by the onboarding's habit page. Same anatomy:
/// the cover cropped to fill, a clear-to-black scrim, and the icon badge with title and
/// description at the bottom. Purely decorative for VoiceOver apart from its text, which is read
/// as one element.
struct ThemedSuggestionPreview: View {
    let iconKey: String
    let title: String
    let description: String
    let themeKey: String?
    let accentColor: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cover

            LinearGradient(
                colors: [.clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(spacing: 10) {
                Image(systemName: HabitIcons.symbol(for: iconKey))
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(accentColor, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if !description.isEmpty {
                        Text(verbatim: description)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var cover: some View {
        if let asset = HabitThemeImages.assetName(for: themeKey) {
            // `Color.clear` sizes the frame; the image fills it and is cropped, so a portrait cover
            // never stretches the card.
            Color.clear
                .overlay(Image(asset).resizable().scaledToFill())
                .clipped()
                .accessibilityHidden(true)
        } else {
            accentColor.opacity(0.25)
        }
    }
}

#Preview("Portadas") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(DefaultHabitTemplates.all) { template in
                ThemedSuggestionPreview(
                    iconKey: template.iconKey,
                    title: template.title,
                    description: HabitThemeImages.description(for: template.themeKey) ?? "",
                    themeKey: template.themeKey,
                    accentColor: HabitPalette.color(at: template.themeColorIndex ?? 0)
                )
            }
            ThemedSuggestionPreview(
                iconKey: "book",
                title: "Sin portada",
                description: "",
                themeKey: nil,
                accentColor: HabitPalette.color(at: 2)
            )
        }
        .padding(16)
    }
    .background(Color.bgDark)
    .preferredColorScheme(.dark)
}
