import SwiftUI

struct OnboardingView: View {
    @StateObject var viewModel: OnboardingViewModel

    /// False on iOS 16, where "Mi Rutina" can't run (SwiftData). The habit page is then not
    /// offered at all — otherwise the user picks a habit that nothing can save, the same
    /// dead end the Home flame button had.
    let isHabitSelectionAvailable: Bool

    private let quotePages: [(image: String, phrase: LocalizedStringKey)] = [
        ("onboarding_01", "Las mejores frases del anime, en la palma de tu mano."),
        ("onboarding_02", "Descubre personajes que te inspiran cada día."),
        ("onboarding_03", "Comparte lo que sientes a través de las palabras del anime."),
    ]

    private var totalPages: Int { quotePages.count + (isHabitSelectionAvailable ? 1 : 0) }
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
                    if isHabitSelectionAvailable {
                        HabitSelectionPageView(viewModel: viewModel)
                            .tag(quotePages.count)
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
                            .font(.headline)
                            .foregroundColor(.bgDark)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                            .frame(minHeight: 52)
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
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.75))
                .padding(.top, 12)
                .padding(.trailing, 24)
        }
    }
}

#Preview("Con hábitos (iOS 17+)") {
    OnboardingView(viewModel: OnboardingViewModel(), isHabitSelectionAvailable: true)
}

#Preview("Sin hábitos (iOS 16)") {
    OnboardingView(viewModel: OnboardingViewModel(), isHabitSelectionAvailable: false)
}

private struct OnboardingPageView: View {
    let imageName: String
    let phrase: LocalizedStringKey

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
/// content, dots + button shared with the parent). Choosing a suggestion shows its cover in a
/// `ThemedSuggestionPreview` under the list, as Android's `HabitOnboardingPage` does; the
/// background is Android's bgDark → surface → bgDark gradient, from the app's tokens.
private struct HabitSelectionPageView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Room the scrolling layout leaves for what `OnboardingView` draws on top of the page: the
    /// status bar and "Saltar" above, the page dots and the button below.
    private static let accessibilityTopInset: CGFloat = 120
    private static let accessibilityBottomInset: CGFloat = 190

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color.bgDark, Color.surface, Color.bgDark],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if dynamicTypeSize.isAccessibilitySize {
                    // At accessibility sizes the page no longer fits between "Saltar" and the
                    // button: it scrolls instead of running under them.
                    ScrollView {
                        VStack(spacing: 24) { sections }
                            .frame(width: geo.size.width)
                            .padding(.top, Self.accessibilityTopInset)
                            .padding(.bottom, Self.accessibilityBottomInset)
                    }
                } else {
                    VStack(spacing: 24) {
                        Spacer()
                        sections
                        Spacer()
                        Spacer()
                    }
                    .frame(width: geo.size.width)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var sections: some View {
        Text("Elige tu primer hábito")
            .scaledFont(size: 24, weight: .bold)
            .foregroundColor(.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

        Text("Puedes cambiarlo o crear otro más tarde, desde Mi Rutina.")
            .scaledFont(size: 14)
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

        if let template = viewModel.selectedTemplate {
            ThemedSuggestionPreview(
                iconKey: template.iconKey,
                title: template.title,
                description: HabitThemeImages.description(for: template.themeKey) ?? "",
                themeKey: template.themeKey,
                accentColor: HabitPalette.color(at: template.themeColorIndex ?? 0)
            )
            .padding(.horizontal, 32)
            .transition(.opacity)
        }
    }

    private func templateRow(_ template: HabitTemplate) -> some View {
        let isSelected = viewModel.selectedTemplateId == template.id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectTemplate(template.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: HabitIcons.symbol(for: template.iconKey))
                    .font(.system(size: 18))
                    .foregroundColor(HabitPalette.color(at: template.themeColorIndex ?? 0))
                    .frame(width: 28)
                Text(verbatim: template.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
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
