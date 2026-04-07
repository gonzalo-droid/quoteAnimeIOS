import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel

    private let pages: [(image: String, phrase: String)] = [
        ("onboarding_01", "Las mejores frases del anime, en la palma de tu mano."),
        ("onboarding_02", "Descubre personajes que te inspiran cada día."),
        ("onboarding_03", "Comparte lo que sientes a través de las palabras del anime."),
    ]

    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()

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

            // Overlay controls
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Saltar") { viewModel.complete() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 56)
                }

                Spacer()

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(viewModel.currentPage == index ? Color.accentPurple : Color.outline)
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
                .padding(.bottom, 48)
            }
        }
    }
}

private struct OnboardingPageView: View {
    let imageName: String
    let phrase: String

    var body: some View {
        ZStack {
            // Background image (or placeholder)
            if let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Color.surface.ignoresSafeArea()
            }

            // Gradient overlay
            LinearGradient(
                colors: [Color.bgDark.opacity(0.2), Color.bgDark.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                Text(phrase)
                    .font(.quoteSerifItalic(size: 22))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 180)
            }
        }
    }
}
