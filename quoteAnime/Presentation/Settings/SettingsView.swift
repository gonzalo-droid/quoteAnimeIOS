import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false

    let premiumGate: PremiumGate

    init(
        getUserPreferences: GetUserPreferencesUseCase,
        updateUserPreferences: UpdateUserPreferencesUseCase,
        notificationScheduler: QuoteNotificationScheduling,
        getAllQuotes: GetAllQuotesUseCase,
        rescheduleNotifications: RescheduleQuoteNotificationsUseCase,
        premiumGate: PremiumGate
    ) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            getUserPreferences: getUserPreferences,
            updateUserPreferences: updateUserPreferences,
            notificationScheduler: notificationScheduler,
            getAllQuotes: getAllQuotes,
            rescheduleNotifications: rescheduleNotifications
        ))
        self.premiumGate = premiumGate
    }

    var body: some View {
        List {
            premiumSection
            contentSection
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
            SafariView(url: AppLinks.privacyPolicy)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showTerms) {
            SafariView(url: AppLinks.termsAndConditions)
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

    /// Entry point to the anime selection. Android renders the same choice inline as a
    /// `FlowRow` of `FilterChip`s; on iOS a Settings row with its current value, pushing a
    /// list of checkmarks, is the native shape for a multiple choice of this size.
    private var contentSection: some View {
        Section("Contenido") {
            Button {
                router.push(.categorySelection)
            } label: {
                HStack {
                    Label("Animes", systemImage: "sparkles")
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text(viewModel.categorySelectionSummary)
                        .foregroundColor(.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .contentShape(Rectangle())
            }
        }
        .listRowBackground(Color.surface)
    }

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

    private var premiumSection: some View {
        Section {
            Button {
                router.push(.paywall)
            } label: {
                Label(
                    premiumGate.isPremium ? "Ya eres premium ✨" : "Hazte Premium",
                    systemImage: "crown.fill"
                )
                .foregroundColor(.textPrimary)
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
                Text("Nueva frase \(viewModel.preferences.widgetUpdateTimesPerDay) veces al día")
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
                item: AppLinks.appStore,
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
        UIApplication.shared.open(AppLinks.appStoreReview)
    }

    private func openSocialURL(_ urlString: String, fallback: String) {
        let deepLink = URL(string: urlString)
        let canOpen = deepLink.map { UIApplication.shared.canOpenURL($0) } ?? false
        let target = canOpen ? deepLink! : URL(string: fallback)!
        UIApplication.shared.open(target)
    }
}

