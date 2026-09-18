import SwiftUI

struct PaywallView: View {
    @StateObject private var viewModel: PaywallViewModel
    @ObservedObject private var premiumGate: PremiumGate
    @Environment(\.dismiss) private var dismiss

    init(premiumGate: PremiumGate, store: PremiumStore) {
        self.premiumGate = premiumGate
        _viewModel = StateObject(
            wrappedValue: PaywallViewModel(premiumGate: premiumGate, store: store)
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topBar

                Circle()
                    .fill(Color.accentPurple.opacity(0.16))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "crown.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.accentPurple)
                    )
                    .padding(.top, 8)

                Text("Hazte Premium")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .padding(.top, 20)

                Text("Desbloquea todo el potencial de tu rutina.")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)

                VStack(spacing: 20) {
                    benefitRow(
                        icon: "infinity",
                        title: "Hábitos ilimitados",
                        body: "Sin el límite de 3 hábitos activos — crea todos los que necesites."
                    )
                    benefitRow(
                        icon: "nosign",
                        title: "Sin anuncios",
                        body: "Comparte tus frases favoritas sin interrupciones publicitarias."
                    )
                    benefitRow(
                        icon: "sparkles",
                        title: "Temas exclusivos",
                        body: "Accede a colecciones temáticas exclusivas, como Pokémon y Black Clover."
                    )
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)

                ctaSection
                    .padding(.top, 36)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .background(Color.bgDark.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $viewModel.isShowingCancelSheet) {
            CancelSubscriptionSheet(
                onKeepPremium: viewModel.onKeepPremium,
                onCancelAnyway: viewModel.onCancelAnyway
            )
            .presentationDetents([.medium, .large])
        }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Volver")
            Spacer()
        }
        .frame(height: 52)
    }

    // MARK: - CTA

    @ViewBuilder
    private var ctaSection: some View {
        if viewModel.uiState.isPremium {
            premiumSection
        } else {
            purchaseSection
        }
    }

    private var premiumSection: some View {
        VStack(spacing: 12) {
            Text("✨ Ya eres premium")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.textPrimary)

            Button(action: viewModel.onManageSubscriptionTapped) {
                Text("Gestionar suscripción")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.accentPurple)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentPurple.opacity(0.6), lineWidth: 1)
                    )
            }

            messageBanner

            #if DEBUG
            // QA affordances only — Android keeps the same control behind BuildConfig.DEBUG.
            Button("Quitar premium (solo pruebas)") { viewModel.debugSetPremium(false) }
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .frame(height: 44)
            #endif
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if viewModel.uiState.isLoadingOffers {
                ProgressView()
                    .tint(.accentPurple)
                    .frame(height: 52)
            } else if viewModel.uiState.offersUnavailable {
                offersUnavailableState
            } else {
                offerList
                subscribeButton
                Text("Cancela cuando quieras desde Ajustes.")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            restoreButton
            messageBanner

            #if DEBUG
            Button("Activar premium (solo pruebas)") { viewModel.debugSetPremium(true) }
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .frame(height: 44)
            #endif
        }
    }

    /// Android's equivalent is a bare sentence with no way out. A retry is cheap here and the
    /// most likely cause — the device was offline when the screen opened — is fixable by the user.
    private var offersUnavailableState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28))
                .foregroundColor(.textSecondary)
            Text("Los planes de suscripción no están disponibles en este momento. Prueba de nuevo más tarde.")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            Button("Reintentar", action: viewModel.retryLoadingOffers)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.accentPurple)
                .frame(height: 44)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private var offerList: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.uiState.offers) { offer in
                let isSelected = viewModel.uiState.selectedOffer?.id == offer.id
                Button { viewModel.selectOffer(offer) } label: {
                    HStack(spacing: 12) {
                        // A radio button next to a single option is noise. The App Store sells
                        // one product id per plan, so today there is exactly one — a second plan
                        // means a second product id, and then the picker earns its place.
                        if viewModel.uiState.offers.count > 1 {
                            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? .accentPurple : .textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: offer.priceDescription)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            if let trial = offer.freeTrialDescription {
                                Text(verbatim: trial)
                                    .font(.system(size: 12))
                                    .foregroundColor(.accentPurple)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 56)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surface)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.accentPurple : Color.outline.opacity(0.4), lineWidth: 1)
                    )
                }
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }

    private var subscribeButton: some View {
        Button { Task { await viewModel.subscribe() } } label: {
            Group {
                if viewModel.uiState.isPurchasing {
                    ProgressView().tint(.bgDark)
                } else {
                    Text("Suscribirme")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.bgDark)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.accentPurple.opacity(viewModel.uiState.canSubscribe ? 1 : 0.5))
            .cornerRadius(16)
        }
        .disabled(!viewModel.uiState.canSubscribe)
    }

    /// Play has no restore action, so Android has none either. The App Store requires one.
    private var restoreButton: some View {
        Button { Task { await viewModel.restorePurchases() } } label: {
            Group {
                if viewModel.uiState.isRestoring {
                    ProgressView().tint(.textSecondary)
                } else {
                    Text("Restaurar compras")
                        .font(.system(size: 14))
                }
            }
            .foregroundColor(.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .disabled(viewModel.uiState.isRestoring)
    }

    /// iOS has no snackbar. An inline banner keeps the message next to the button that caused it
    /// instead of interrupting with an alert the user has to dismiss.
    @ViewBuilder
    private var messageBanner: some View {
        if let message = viewModel.uiState.message {
            Button(action: viewModel.onMessageShown) {
                Text(verbatim: message.text)
                    .font(.system(size: 13))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.surface)
                    .cornerRadius(12)
            }
            .accessibilityHint("Toca para descartar")
        }
    }

    private func benefitRow(icon: String, title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(Color.surface)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.accentPurple)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(body)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
            }
        }
        // Without this each row is only as wide as its text and gets centred on its own, so the
        // icons stop lining up as soon as one body wraps differently (visible in English).
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
