import SwiftUI

/// Full-screen quote detail reused by both Home (no back button, color fallback) and Catalog (back button, dark fallback).
struct QuoteDetailView<Actions: View>: View {
    let quote: Quote
    var onBack: (() -> Void)? = nil
    /// Gradient shown when quote.imageUrl is nil. Defaults to dark gradient when not provided.
    var colorFallback: LinearGradient? = nil
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Background: anime image or fallback gradient
                backgroundLayer(geo: geo)

                // Dark overlay: top 45% → center 72% → bottom 92%
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.45), location: 0),
                        .init(color: .black.opacity(0.72), location: 0.5),
                        .init(color: .black.opacity(0.92), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Main content column
                VStack(spacing: 0) {
                    Spacer()
                    quoteBlock
                    Spacer()
                    actions()
                        .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                }

                // Optional back button
                if let onBack {
                    VStack {
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.black.opacity(0.35))
                                    .clipShape(Circle())
                            }
                            .padding(.leading, 16)
                            .padding(.top, geo.safeAreaInsets.top + 8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Subviews

    @ViewBuilder
    private func backgroundLayer(geo: GeometryProxy) -> some View {
        if let urlStr = quote.imageUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geo.size.width,
                            height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
                        )
                        .clipped()
                default:
                    activeFallback
                }
            }
            .ignoresSafeArea()
        } else {
            activeFallback
        }
    }

    private var activeFallback: some View {
        (colorFallback ?? LinearGradient(
            colors: [Color(hex: "#0C0C1E"), Color(hex: "#1A0E2E")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
        .ignoresSafeArea()
    }

    private var quoteBlock: some View {
        VStack(spacing: 0) {
            // Decorative opening quote mark
            Text("\u{201C}")
                .font(.quoteSerif(size: 96))
                .foregroundColor(.accentPurple.opacity(0.20))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.bottom, -32)

            // Quote text
            Text(quote.quote)
                .font(.quoteSerifItalic(size: 20))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 32)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 64, height: 1)
                .padding(.vertical, 18)

            // Author
            Text("— \(quote.author)")
                .font(.quoteSerif(size: 15))
                .foregroundColor(.white.opacity(0.85))

            // Anime name
            Text(quote.anime.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(2.5)
                .foregroundColor(.accentPurple)
                .padding(.top, 6)
        }
    }
}
