import SwiftUI

struct CatalogView: View {
    @StateObject private var viewModel: CatalogViewModel
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    init(
        getAllQuotesUseCase: GetAllQuotesUseCase,
        getFavoriteQuotesUseCase: GetFavoriteQuotesUseCase,
        toggleFavoriteUseCase: ToggleFavoriteUseCase
    ) {
        _viewModel = StateObject(wrappedValue: CatalogViewModel(
            getAllQuotesUseCase: getAllQuotesUseCase,
            getFavoriteQuotesUseCase: getFavoriteQuotesUseCase,
            toggleFavoriteUseCase: toggleFavoriteUseCase
        ))
    }

    var body: some View {
        Group {
            if let selectedQuote = viewModel.uiState.selectedQuote {
                // VISTA 3 — Detail full-screen (manages its own background)
                detailView(quote: selectedQuote)
                    .transition(.opacity)
            } else if let filter = viewModel.uiState.selectedFilter {
                // VISTA 2 — Quote list
                listView(filter: filter)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // VISTA 1 — Selector
                selectorView
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        // Background extends under status bar; content VStacks respect safe area naturally
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDark.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: viewModel.uiState.selectedFilter)
        .animation(.easeInOut(duration: 0.20), value: viewModel.uiState.selectedQuote?.id)
        .navigationBarHidden(true)
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let img = viewModel.shareImage {
                ActivityViewController(activityItems: [img])
            }
        }
    }

    // MARK: - Vista 1: Selector

    private var selectorView: some View {
        VStack(spacing: 0) {
            // TopBar
            topBar(title: "Explorar", onBack: { dismiss() })

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Main action cards row
                    HStack(spacing: 12) {
                        mainFilterCard(
                            title: "Favoritos",
                            icon: "heart.fill",
                            color: .heartRed,
                            filter: .favorites
                        )
                        mainFilterCard(
                            title: "Todas",
                            icon: "rectangle.stack.fill",
                            color: .accentPurple,
                            filter: .all
                        )
                    }
                    .padding(.horizontal, 16)

                    // Emotion grid (2 columns)
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(allEmotionCategories) { emotion in
                            emotionTile(emotion)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .padding(.top, 16)
            }
        }
    }

    private func mainFilterCard(title: String, icon: String, color: Color, filter: CatalogFilter) -> some View {
        Button { viewModel.onFilterSelected(filter) } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
        }
    }

    private func emotionTile(_ emotion: EmotionCategory) -> some View {
        Button {
            viewModel.onFilterSelected(.byEmotion(categoryId: emotion.id, label: emotion.label))
        } label: {
            VStack(spacing: 8) {
                Text(emotion.emoji)
                    .font(.system(size: 32))
                Text(emotion.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                emotion.color.opacity(0.15)
                    .background(Color.surface)
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(emotion.color.opacity(0.35), lineWidth: 1)
            )
        }
    }

    // MARK: - Vista 2: Quote List

    private func listView(filter: CatalogFilter) -> some View {
        VStack(spacing: 0) {
            topBar(title: filter.label, onBack: { viewModel.onBackFromList() })

            if viewModel.uiState.isLoading {
                Spacer()
                ProgressView().tint(.accentPurple)
                Spacer()
            } else if viewModel.uiState.isEmpty {
                Spacer()
                Text("Sin frases en esta categoría")
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.uiState.quotes) { quote in
                            QuoteCard(
                                quote: quote,
                                onFavorite: { viewModel.onToggleFavorite(quote) }
                            )
                            .onTapGesture { viewModel.onQuoteSelected(quote) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Vista 3: Detail

    private func detailView(quote: Quote) -> some View {
        QuoteDetailView(quote: quote, onBack: { viewModel.onBackFromDetail() }) {
            HStack(spacing: 20) {
                // Favorite
                CircleActionButton(
                    icon: quote.isFavorite ? "heart.fill" : "heart",
                    color: quote.isFavorite ? .heartRed : .white
                ) {
                    viewModel.onToggleFavorite(quote)
                }

                // Share
                CircleActionButton(icon: "square.and.arrow.up", color: .white) {
                    ShareInterstitialManager.shared.onShareRequested {
                        viewModel.buildShareImage(for: quote)
                    }
                }
            }
        }
    }

    // MARK: - Shared TopBar

    private func topBar(title: String, onBack: @escaping () -> Void) -> some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .padding(.leading, 8)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Spacer to balance the back button width
            Color.clear.frame(width: 44, height: 44)
                .padding(.trailing, 8)
        }
        .frame(height: 52)
        .background(Color.bgDark)
    }
}

// MARK: - Reusable circular action button

private struct CircleActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 52, height: 52)
                .background(Color.black.opacity(0.45))
                .clipShape(Circle())
        }
    }
}
