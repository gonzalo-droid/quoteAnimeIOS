import SwiftUI
import StoreKit

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false

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
            socialSection
            versionSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.bgDark)
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $showPrivacyPolicy) {
            SafariView(url: URL(string: "https://quote-anime-web.vercel.app/privacy-policy")!)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showTerms) {
            SafariView(url: URL(string: "https://quote-anime-web.vercel.app/terms-and-conditions")!)
                .ignoresSafeArea()
        }
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
        Section("Apóyanos") {
            Button {
                requestReview()
            } label: {
                Label("Déjanos una reseña", systemImage: "star.fill")
                    .foregroundColor(.textPrimary)
            }

            ShareLink(
                item: URL(string: "https://apps.apple.com/app/id6762100338")!,
                subject: Text("QuoteAnime"),
                message: Text("¡Descubre QuoteAnime! Las mejores frases de tus animes favoritos 🌟 Descárgala gratis:")
            ) {
                Label("Compartir la app", systemImage: "square.and.arrow.up")
                    .foregroundColor(.textPrimary)
            }
        }
        .listRowBackground(Color.surface)
    }

    private var socialSection: some View {
        Section("Síguenos") {
            Button { openSocialURL("instagram://user?username=quoteanimeapp",
                                   fallback: "https://www.instagram.com/animequoteapp/") } label: {
                Label {
                    Text("Instagram").foregroundColor(.textPrimary)
                } icon: {
                    Image("icon_instagram")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.textPrimary)
                }
            }
            Button { openSocialURL("fb://profile/quoteanimeapp",
                                   fallback: "https://www.facebook.com/share/1Ay18mtNZh/?mibextid=wwXIfr") } label: {
                Label {
                    Text("Facebook").foregroundColor(.textPrimary)
                } icon: {
                    Image("icon_facebook")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.textPrimary)
                }
            }
            /*Button { openSocialURL("tiktok://user?username=quoteanimeapp",
                                   fallback: "https://www.tiktok.com/@quoteanimeapp") } label: {
                Label {
                    Text("TikTok").foregroundColor(.textPrimary)
                } icon: {
                    Image("icon_tiktok")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.textPrimary)
                }
            }*/
        }
        .listRowBackground(Color.surface)
    }

    private var versionSection: some View {
        Section("Información") {
            Button {
                showPrivacyPolicy = true
            } label: {
                Label("Política de privacidad", systemImage: "hand.raised.fill")
                    .foregroundColor(.textPrimary)
            }

            Button {
                showTerms = true
            } label: {
                Label("Términos y condiciones", systemImage: "doc.text.fill")
                    .foregroundColor(.textPrimary)
            }

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
        } else {
            openAppStoreReview()
        }
    }

    private func openAppStoreReview() {
        if let url = URL(string: "https://apps.apple.com/app/id6762100338?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    private func openSocialURL(_ urlString: String, fallback: String) {
        let deepLink = URL(string: urlString)
        let canOpen = deepLink.map { UIApplication.shared.canOpenURL($0) } ?? false
        let target = canOpen ? deepLink! : URL(string: fallback)!
        UIApplication.shared.open(target)
    }
}

