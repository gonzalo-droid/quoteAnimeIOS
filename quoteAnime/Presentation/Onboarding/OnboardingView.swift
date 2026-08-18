import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel

    private let quotePages: [(image: String, phrase: String)] = [
        ("onboarding_01", "Las mejores frases del anime, en la palma de tu mano."),
        ("onboarding_02", "Descubre personajes que te inspiran cada día."),
        ("onboarding_03", "Comparte lo que sientes a través de las palabras del anime."),
    ]

    private var totalPages: Int { quotePages.count + 1 }
    private var isLastPage: Bool { viewModel.currentPage == totalPages - 1 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // TabView fullscreen — ignores safe area so image fills the entire screen
                TabView(selection: $viewModel.currentPage) {
                    ForEach(quotePages.indices, id: \.self) { index in
                        OnboardingPageView(
                            imageName: quotePages[index].image,
                            phrase: quotePages[index].phrase
                        )
                        .tag(index)
                    }
                    HabitSelectionPageView(viewModel: viewModel)
                        .tag(quotePages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentPage)
                .ignoresSafeArea()

                // Bottom controls — use geo from outer GeometryReader (before ignoresSafeArea)
                VStack(spacing: 0) {
                    Spacer()

                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule()
                                .fill(viewModel.currentPage == index ? Color.accentPurple : Color.white.opacity(0.4))
                                .frame(width: viewModel.currentPage == index ? 20 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: viewModel.currentPage)
                        }
                    }

                    // Next / Start button
                    Button {
                        if !isLastPage {
                            viewModel.currentPage += 1
                        } else {
                            viewModel.complete()
                        }
                    } label: {
                        Text(isLastPage ? "Comenzar" : "Siguiente")
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

/// 4th page — same visual language as the quote pages (dark gradient background, centered
/// content, dots + button shared with the parent) but no bundled cover image per template
/// yet on iOS, so the background is a plain themed gradient instead of anime art.
private struct HabitSelectionPageView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color.bgDark, Color(hex: "#1A1040")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 24) {
                    Spacer()

                    Text("Elegí tu primer hábito")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Podés cambiarlo o crear otro más tarde, desde Mi Rutina.")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    VStack(spacing: 12) {
                        ForEach(viewModel.habitTemplates) { template in
                            templateRow(template)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                    Spacer()
                    Spacer()
                }
                .frame(width: geo.size.width)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    private func templateRow(_ template: HabitTemplate) -> some View {
        let isSelected = viewModel.selectedTemplateId == template.id
        return Button {
            viewModel.selectTemplate(template.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: HabitIcons.symbol(for: template.iconKey))
                    .font(.system(size: 18))
                    .foregroundColor(HabitPalette.color(at: template.themeColorIndex ?? 0))
                    .frame(width: 28)
                Text(template.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .accentPurple : .textSecondary)
            }
            .padding(14)
            .background(Color.surface.opacity(0.7))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentPurple : Color.outline.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}
