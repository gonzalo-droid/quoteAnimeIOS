import SwiftUI

/// Lets the user pick which animes they want quotes from.
///
/// Android shows this as a `FlowRow` of Material `FilterChip`s; on iOS the equivalent job is a
/// pushed list with checkmarks — the same control Settings.app uses for a multiple choice.
/// No `.searchable`: the catalogue is 19 animes today (derived from `Set(anime)`), which is
/// about a screen and a half — a search field would be chrome for nothing. Add it if the
/// catalogue ever outgrows ~30 rows.
struct CategorySelectionView: View {
    @StateObject private var viewModel: CategorySelectionViewModel

    init(
        getCategories: GetCategoriesUseCase,
        getUserPreferences: GetUserPreferencesUseCase,
        updateUserPreferences: UpdateUserPreferencesUseCase,
        rescheduleNotifications: RescheduleQuoteNotificationsUseCase
    ) {
        _viewModel = StateObject(wrappedValue: CategorySelectionViewModel(
            getCategories: getCategories,
            getUserPreferences: getUserPreferences,
            updateUserPreferences: updateUserPreferences,
            rescheduleNotifications: rescheduleNotifications
        ))
    }

    var body: some View {
        List {
            Section {
                selectionRow(title: "Todos los animes", isSelected: viewModel.allSelected) {
                    viewModel.selectAll()
                }
            } footer: {
                Text("Elegí de qué animes querés ver frases en el inicio y recibir por notificación. Si no elegís ninguno, se muestran todos.")
                    .foregroundColor(.textSecondary)
            }
            .listRowBackground(Color.surface)

            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView().tint(.accentPurple)
                        Spacer()
                    }
                }
                .listRowBackground(Color.surface)
            } else if viewModel.loadFailed {
                Section {
                    Text("No pudimos cargar los animes. Revisá tu conexión y volvé a entrar.")
                        .foregroundColor(.textSecondary)
                }
                .listRowBackground(Color.surface)
            } else if viewModel.categories.isEmpty {
                Section {
                    Text("Todavía no hay animes disponibles.")
                        .foregroundColor(.textSecondary)
                }
                .listRowBackground(Color.surface)
            } else {
                Section("Animes") {
                    ForEach(viewModel.categories) { category in
                        selectionRow(
                            title: category.name,
                            isSelected: viewModel.isSelected(category.id)
                        ) {
                            viewModel.toggle(category.id)
                        }
                    }
                }
                .listRowBackground(Color.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgDark)
        .navigationTitle("Animes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await viewModel.load() }
    }

    // MARK: - Rows

    private func selectionRow(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentPurple)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    let repository = PreviewQuoteRepository()
    return NavigationStack {
        CategorySelectionView(
            getCategories: GetCategoriesUseCase(repository: repository),
            getUserPreferences: GetUserPreferencesUseCase(
                repository: UserPreferencesRepositoryImpl(store: UserPreferencesStore())
            ),
            updateUserPreferences: UpdateUserPreferencesUseCase(
                repository: UserPreferencesRepositoryImpl(store: UserPreferencesStore())
            ),
            rescheduleNotifications: RescheduleQuoteNotificationsUseCase(
                getAllQuotes: GetAllQuotesUseCase(repository: repository),
                scheduler: NotificationScheduler()
            )
        )
    }
    .preferredColorScheme(.dark)
}

/// Preview-only stand-in so the list renders without Firebase.
private final class PreviewQuoteRepository: QuoteRepository {
    private let quotes = ["Naruto", "One Piece", "Vinland Saga", "Bleach", "Haikyuu!!"]
        .enumerated()
        .map { Quote(id: "\($0.offset)", quote: "…", author: "…", anime: $0.element) }

    func fetchAllQuotes() async throws -> [Quote] { quotes }
    func fetchQuotesByAnime(_ anime: String) async throws -> [Quote] {
        quotes.filter { $0.anime == anime }
    }
    func toggleFavorite(_ quote: Quote) async throws {}
    func fetchFavorites() async throws -> [Quote] { [] }
    func isFavorite(id: String) async -> Bool { false }
}
