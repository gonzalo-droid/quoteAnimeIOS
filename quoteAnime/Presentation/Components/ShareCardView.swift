import SwiftUI

/// Rendered to a UIImage via ImageRenderer for sharing.
struct ShareCardView: View {
    let quote: Quote

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0C0C1E"), Color(hex: "#1A1040")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Decorative quote mark
                Text("\u{201C}")
                    .font(.quoteSerif(size: 52))
                    .foregroundColor(.accentPurple.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.bottom, -20)

                // Quote text
                Text(quote.quote)
                    .font(.quoteSerifItalic(size: 17))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)

                // Divider
                Rectangle()
                    .fill(Color.outline)
                    .frame(width: 32, height: 1)
                    .padding(.vertical, 16)

                Text("— \(quote.author)")
                    .font(.quoteSerif(size: 13))
                    .foregroundColor(.textSecondary)

                Text(quote.anime.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .kerning(2.5)
                    .foregroundColor(.accentPurple)
                    .padding(.top, 5)

                Spacer()

                // Watermark
                Text("Quote Anime")
                    .font(.system(size: 9, weight: .light))
                    .foregroundColor(.textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .padding(.top, 22)
        }
        .frame(width: 320, height: 420)
        .cornerRadius(18)
    }
}
