import SwiftUI

// MARK: - Container (reads env, initialises ViewModel)

struct HomeContainerView: View {
    @EnvironmentObject private var deps: AppDependencies
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        HomeContentView(viewModel: viewModel)
            .task { viewModel.setup(
                getAllQuotes: deps.getAllQuotesUseCase,
                toggleFavorite: deps.toggleFavoriteUseCase,
                getCategoriesUseCase: deps.getCategoriesUseCase,
                getUserPreferences: deps.getUserPreferencesUseCase,
                notificationScheduler: deps.notificationScheduler,
                router: router
            )}
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let img = viewModel.shareImage {
                    ActivityViewController(activityItems: [img])
                }
            }
    }
}

// MARK: - Content

private struct HomeContentView: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                if viewModel.isLoading {
                    ZStack {
                        Color.bgDark.ignoresSafeArea()
                        ProgressView().tint(.accentPurple)
                    }
                } else if viewModel.quotes.isEmpty {
                    ZStack {
                        Color.bgDark.ignoresSafeArea()
                        Text("Sin frases disponibles").foregroundColor(.textSecondary)
                    }
                } else {
                    pager(geo: geo)
                }
            }
            .ignoresSafeArea()

            // Routine + Settings buttons — safe area handled naturally by the ZStack
            VStack {
                HStack {
                    Spacer()
                    Button { router.push(.routine) } label: {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(14)
                    }
                    Button { router.push(.settings) } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(14)
                    }
                }
                .padding(.top, 4)
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func pager(geo: GeometryProxy) -> some View {
        if #available(iOS 17, *) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.quotes.indices, id: \.self) { index in
                        pageView(for: index)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .ignoresSafeArea()
        } else {
            TabView(selection: $viewModel.currentIndex) {
                ForEach(viewModel.quotes.indices, id: \.self) { index in
                    pageView(for: index).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
        }
    }

    private func pageView(for index: Int) -> some View {
        let quote = viewModel.quotes[index]
        return QuotePageView(
            quote: quote,
            colorFallback: viewModel.gradient(for: index),
            onFavorite: { Task { await viewModel.toggleFavorite(at: index) } },
            onShare:    { viewModel.currentIndex = index; viewModel.buildShareImage() },
            onExplore:  { viewModel.openCatalog() }
        )
    }
}

// MARK: - Quote Page

private struct QuotePageView: View {
    let quote: Quote
    let colorFallback: LinearGradient
    let onFavorite: () -> Void
    let onShare: () -> Void
    let onExplore: () -> Void

    @State private var favoriteScale: CGFloat = 1

    var body: some View {
        QuoteDetailView(quote: quote, colorFallback: colorFallback) {
            VStack(spacing: 0) {
                // Action buttons row
                HStack(spacing: 36) {
                    // Favorite
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                            favoriteScale = 1.4
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.2)) { favoriteScale = 1 }
                        }
                        onFavorite()
                    } label: {
                        Image(systemName: quote.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 26))
                            .foregroundColor(quote.isFavorite ? .heartRed : .white.opacity(0.8))
                            .scaleEffect(favoriteScale)
                    }

                    // Share
                    Button {
                        ShareInterstitialManager.shared.onShareRequested(onProceed: onShare)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    // Explore catalog
                    Button(action: onExplore) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.bottom, 16)

                // Banner desactivado temporalmente — reemplazado por intersticial en flujo de compartir
                // BannerAdView(adUnitID: AdConstants.homeBannerID)
                //     .frame(height: 50)
                //     .padding(.bottom, 12)
            }
        }
    }
}
