import SwiftUI

struct CatalogView: View {
    @StateObject private var viewModel: CatalogViewModel
    @EnvironmentObject private var router: AppRouter

    init(
        getCategoriesUseCase: GetCategoriesUseCase,
        getQuotesByCategoryUseCase: GetQuotesByCategoryUseCase,
        getFavoriteQuotesUseCase: GetFavoriteQuotesUseCase,
        toggleFavoriteUseCase: ToggleFavoriteUseCase,
        initialCategoryId: String? = nil
    ) {
        _viewModel = StateObject(wrappedValue: CatalogViewModel(
            getCategoriesUseCase: getCategoriesUseCase,
            getQuotesByCategoryUseCase: getQuotesByCategoryUseCase,
            getFavoriteQuotesUseCase: getFavoriteQuotesUseCase,
            toggleFavoriteUseCase: toggleFavoriteUseCase,
            initialCategoryId: initialCategoryId
        ))
    }

    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()

            VStack(spacing: 0) {
                categoryChips
                    .padding(.vertical, 12)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(.accentPurple)
                    Spacer()
                } else if viewModel.quotes.isEmpty {
                    Spacer()
                    Text(viewModel.selectedTab == nil ? "Sin favoritos" : "Sin frases en esta categoría")
                        .foregroundColor(.textSecondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.quotes) { quote in
                                QuoteCard(
                                    quote: quote,
                                    onFavorite: { Task { await viewModel.toggleFavorite(quote) } }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle("Explorar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.onAppear() }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(label: "Favoritos", isSelected: viewModel.selectedTab == nil) {
                    viewModel.selectTab(nil)
                }
                ForEach(viewModel.categories) { category in
                    chip(label: category.name, isSelected: viewModel.selectedTab == category.id) {
                        viewModel.selectTab(category.id)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .bgDark : .textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentPurple : Color.surface)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.outline, lineWidth: 1)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
