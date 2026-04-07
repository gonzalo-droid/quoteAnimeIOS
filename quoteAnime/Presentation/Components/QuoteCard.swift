import SwiftUI

struct QuoteCard: View {
    let quote: Quote
    let onFavorite: () -> Void

    @State private var heartScale: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(quote.quote)
                .font(.quoteSerifItalic(size: 16))
                .foregroundColor(.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("— \(quote.author)")
                        .font(.quoteSerif(size: 13))
                        .foregroundColor(.textSecondary)

                    Text(quote.anime.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .kerning(2)
                        .foregroundColor(.accentPurple)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        heartScale = 1.35
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2)) { heartScale = 1 }
                    }
                    onFavorite()
                } label: {
                    Image(systemName: quote.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(quote.isFavorite ? .heartRed : .textSecondary)
                        .scaleEffect(heartScale)
                }
            }
        }
        .padding(16)
        .background(Color.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.outline, lineWidth: 0.5)
        )
    }
}
