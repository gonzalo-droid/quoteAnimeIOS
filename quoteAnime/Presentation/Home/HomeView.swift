import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    init(deps: AppDependencies, router: AppRouter) {
        _viewModel = StateObject(wrappedValue: HomeViewModel())
        // Defer setup to .task since StateObject init doesn't allow capturing deps here cleanly
        _ = deps; _ = router
    }

    // Two-phase init: pass deps via environment via the container view.
    // See HomeContainerView below.
    @EnvironmentObject private var deps: AppDependencies
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack(alignment: .top) {
            quotesPager
            topBar
        }
        .task { viewModel.setup(
            getAllQuotes: deps.getAllQuotesUseCase,
            toggleFavorite: deps.toggleFavoriteUseCase,
            getCategoriesUseCase: deps.getCategoriesUseCase,
            getUserPreferences: deps.getUserPreferencesUseCase,
            router: router
        )}
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let img = viewModel.shareImage {
                ActivityViewController(activityItems: [img])
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var quotesPager: some View {
        if viewModel.isLoading {
            ZStack {
                Color.bgDark.ignoresSafeArea()
                ProgressView().tint(.accentPurple)
            }
        } else if let error = viewModel.loadError {
            ZStack {
                Color.bgDark.ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("No se pudo cargar").foregroundColor(.textPrimary)
                    Text(error).font(.caption).foregroundColor(.textSecondary)
                    Button("Reintentar") { Task { await viewModel.loadQuotes() } }
                        .foregroundColor(.accentPurple)
                }
            }
        } else {
            GeometryReader { geo in
                if #available(iOS 17, *) {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.quotes.indices, id: \.self) { index in
                                QuotePageView(
                                    quote: viewModel.quotes[index],
                                    gradient: viewModel.gradient(for: index),
                                    onFavorite: { Task { await viewModel.toggleFavoriteForCurrentQuote() } },
                                    onShare:    { viewModel.buildShareImage() },
                                    onExplore:  { viewModel.openCatalog(categoryId: viewModel.quotes[index].anime) }
                                )
                                .containerRelativeFrame([.horizontal, .vertical])
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: .init(
                        get: { viewModel.currentIndex },
                        set: { if let i = $0 { viewModel.currentIndex = i } }
                    ))
                    .ignoresSafeArea()
                } else {
                    TabView(selection: $viewModel.currentIndex) {
                        ForEach(viewModel.quotes.indices, id: \.self) { index in
                            QuotePageView(
                                quote: viewModel.quotes[index],
                                gradient: viewModel.gradient(for: index),
                                onFavorite: { Task { await viewModel.toggleFavoriteForCurrentQuote() } },
                                onShare:    { viewModel.buildShareImage() },
                                onExplore:  { viewModel.openCatalog(categoryId: viewModel.quotes[index].anime) }
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                }
            }
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button { viewModel.openSettings() } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.textSecondary)
                    .padding(12)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}

// MARK: - Quote Page

private struct QuotePageView: View {
    let quote: Quote
    let gradient: LinearGradient
    let onFavorite: () -> Void
    let onShare: () -> Void
    let onExplore: () -> Void

    @State private var favoriteScale: CGFloat = 1

    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Decorative quote mark
                Text("\u{201C}")
                    .font(.quoteSerif(size: 96))
                    .foregroundColor(.accentPurple.opacity(0.18))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.bottom, -32)

                // Quote text
                Text(quote.quote)
                    .font(.quoteSerifItalic(size: 20))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 32)

                // Divider
                Rectangle()
                    .fill(Color.outline)
                    .frame(width: 36, height: 1)
                    .padding(.vertical, 18)

                // Author
                Text("— \(quote.author)")
                    .font(.quoteSerif(size: 15))
                    .foregroundColor(.textSecondary)

                // Anime
                Text(quote.anime.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .kerning(2.5)
                    .foregroundColor(.accentPurple)
                    .padding(.top, 6)

                Spacer()

                // Action buttons
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
                            .foregroundColor(quote.isFavorite ? .heartRed : .textSecondary)
                            .scaleEffect(favoriteScale)
                    }

                    // Share
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 24))
                            .foregroundColor(.textSecondary)
                    }

                    // Explore category
                    Button(action: onExplore) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(.bottom, 20)

                // AdMob banner
                BannerAdView(adUnitID: AdConstants.homeBannerID)
                    .frame(height: 50)
                    .padding(.bottom, 12)
            }
        }
    }
}

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
                router: router
            )}
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let img = viewModel.shareImage {
                    ActivityViewController(activityItems: [img])
                }
            }
    }
}

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

            // Settings button
            HStack {
                Spacer()
                Button { router.push(.settings) } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.textSecondary)
                        .padding(14)
                }
            }
            .padding(.top, 8)
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
        QuotePageView(
            quote: viewModel.quotes[index],
            gradient: viewModel.gradient(for: index),
            onFavorite: { Task { await viewModel.toggleFavoriteForCurrentQuote() } },
            onShare:    { viewModel.currentIndex = index; viewModel.buildShareImage() },
            onExplore:  { viewModel.openCatalog(categoryId: viewModel.quotes[index].anime) }
        )
    }
}
