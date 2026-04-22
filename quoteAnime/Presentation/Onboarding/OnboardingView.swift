import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel

    private let pages: [(image: String, phrase: String)] = [
        ("onboarding_01", "Las mejores frases del anime, en la palma de tu mano."),
        ("onboarding_02", "Descubre personajes que te inspiran cada día."),
        ("onboarding_03", "Comparte lo que sientes a través de las palabras del anime."),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // TabView fullscreen — ignores safe area so image fills the entire screen
                TabView(selection: $viewModel.currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(
                            imageName: pages[index].image,
                            phrase: pages[index].phrase
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentPage)
                .ignoresSafeArea()

                // Bottom controls — use geo from outer GeometryReader (before ignoresSafeArea)
                VStack(spacing: 0) {
                    Spacer()

                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(viewModel.currentPage == index ? Color.accentPurple : Color.white.opacity(0.4))
                                .frame(width: viewModel.currentPage == index ? 20 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: viewModel.currentPage)
                        }
                    }

                    // Next / Start button
                    Button {
                        if viewModel.currentPage < pages.count - 1 {
                            viewModel.currentPage += 1
                        } else {
                            viewModel.complete()
                        }
                    } label: {
                        Text(viewModel.currentPage < pages.count - 1 ? "Siguiente" : "Comenzar")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.bgDark)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.accentPurple)
                            .cornerRadius(14)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 16)
                }
            }
        }
        .ignoresSafeArea()
        // Skip button outside ignoresSafeArea so SwiftUI respects the safe area automatically
        .overlay(alignment: .topTrailing) {
            Button("Saltar") { viewModel.complete() }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
                .padding(.top, 12)
                .padding(.trailing, 24)
        }
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel())
}

private struct OnboardingPageView: View {
    let imageName: String
    let phrase: String

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background image — fills the full screen
                if let uiImage = UIImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color.surface
                }

                // Same gradient as QuoteDetailView
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.45), location: 0),
                        .init(color: .black.opacity(0.72), location: 0.5),
                        .init(color: .black.opacity(0.92), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Quote centered — same layout as HomeView quote block
                VStack(spacing: 0) {
                    Text(phrase)
                        .font(.quoteSerifItalic(size: 22))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                // Shift slightly above center to leave room for bottom controls
                .offset(y: -40)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}
