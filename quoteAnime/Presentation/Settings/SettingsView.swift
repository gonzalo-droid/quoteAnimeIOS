import SwiftUI
import StoreKit

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var router: AppRouter

    init(
        getUserPreferences: GetUserPreferencesUseCase,
        updateUserPreferences: UpdateUserPreferencesUseCase,
        notificationScheduler: NotificationScheduler,
        getAllQuotes: GetAllQuotesUseCase
    ) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            getUserPreferences: getUserPreferences,
            updateUserPreferences: updateUserPreferences,
            notificationScheduler: notificationScheduler,
            getAllQuotes: getAllQuotes
        ))
    }

    var body: some View {
        List {
            notificationsSection
            widgetSection
            ratingSection
            versionSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgDark)
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.onAppear() }
        .alert("Permiso de notificaciones", isPresented: $viewModel.showPermissionAlert) {
            Button("Ir a Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Las notificaciones están desactivadas. Actívalas en Ajustes del sistema.")
        }
    }

    // MARK: - Sections

    private var notificationsSection: some View {
        Section("Notificaciones") {
            Toggle("Activar notificaciones", isOn: Binding(
                get: { viewModel.preferences.notificationsEnabled },
                set: { viewModel.preferences.notificationsEnabled = $0
                    Task { await viewModel.toggleNotifications() }
                }
            ))
            .tint(.accentPurple)

            if viewModel.preferences.notificationsEnabled {

                DatePicker(
                    "Desde",
                    selection: Binding(
                        get: { viewModel.notificationStartDate },
                        set: { viewModel.notificationStartDate = $0; viewModel.savePreferences() }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .tint(.accentPurple)

                DatePicker(
                    "Hasta",
                    selection: Binding(
                        get: { viewModel.notificationEndDate },
                        set: { viewModel.notificationEndDate = $0; viewModel.savePreferences() }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .tint(.accentPurple)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Frecuencia: \(viewModel.preferences.notificationFrequency) veces al día")
                        .font(.subheadline)
                        .foregroundColor(.textPrimary)
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.preferences.notificationFrequency) },
                            set: { viewModel.preferences.notificationFrequency = Int($0); viewModel.savePreferences() }
                        ),
                        in: 1...10, step: 1
                    )
                    .tint(.accentPurple)
                }
            }
        }
        .listRowBackground(Color.surface)
    }

    private var widgetSection: some View {
        Section("Widget") {
            Button {
                router.push(.widgetTutorial)
            } label: {
                Label("Cómo agregar el widget", systemImage: "plus.square.dashed")
                    .foregroundColor(.textPrimary)
            }

            Text("Puedes redimensionar el widget manteniendo pulsado sobre él.")
                .font(.caption)
                .foregroundColor(.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Actualizaciones: \(viewModel.preferences.widgetUpdateTimesPerDay) por día")
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)
                Slider(
                    value: Binding(
                        get: { Double(viewModel.preferences.widgetUpdateTimesPerDay) },
                        set: { viewModel.preferences.widgetUpdateTimesPerDay = Int($0); viewModel.savePreferences() }
                    ),
                    in: 1...8, step: 1
                )
                .tint(.accentPurple)
            }
        }
        .listRowBackground(Color.surface)
    }

    private var ratingSection: some View {
        Section("Valorar") {
            Button {
                requestReview()
            } label: {
                Label("Calificar la app", systemImage: "star.fill")
                    .foregroundColor(.textPrimary)
            }
        }
        .listRowBackground(Color.surface)
    }

    private var versionSection: some View {
        Section("Información") {
            HStack {
                Text("Versión")
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(.textSecondary)
            }
        }
        .listRowBackground(Color.surface)
    }

    // MARK: - Review

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}

#if DEBUG
private struct PreviewQuoteRepository: QuoteRepository {
    func fetchAllQuotes() async throws -> [Quote] { [] }
    func fetchQuotesByAnime(_ anime: String) async throws -> [Quote] { [] }
    func toggleFavorite(_ quote: Quote) async throws {}
    func fetchFavorites() async throws -> [Quote] { [] }
    func isFavorite(id: String) async -> Bool { false }
}
private struct PreviewPreferencesRepository: UserPreferencesRepository {
    func getPreferences() -> UserPreferences { UserPreferences() }
    func savePreferences(_ preferences: UserPreferences) {}
    func isOnboardingCompleted() -> Bool { true }
    func setOnboardingCompleted(_ completed: Bool) {}
}
#endif

#Preview {
    let prefsRepo = PreviewPreferencesRepository()
    let quoteRepo = PreviewQuoteRepository()
    return NavigationStack {
        SettingsView(
            getUserPreferences: GetUserPreferencesUseCase(repository: prefsRepo),
            updateUserPreferences: UpdateUserPreferencesUseCase(repository: prefsRepo),
            notificationScheduler: NotificationScheduler(),
            getAllQuotes: GetAllQuotesUseCase(repository: quoteRepo)
        )
    }
    .environmentObject(AppRouter())
}
