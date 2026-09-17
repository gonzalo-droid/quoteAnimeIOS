import SwiftUI

struct PaywallView: View {
    @StateObject private var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss

    init(premiumGate: PremiumGate) {
        _viewModel = StateObject(wrappedValue: PaywallViewModel(premiumGate: premiumGate))
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

    @ViewBuilder
    private var ctaSection: some View {
        if viewModel.uiState.isPremium {
            VStack(spacing: 8) {
                Text("✨ Ya eres premium")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
                #if DEBUG
                // QA affordance only — Android keeps the same control behind BuildConfig.DEBUG.
                Button("Quitar premium (solo pruebas)", action: viewModel.onRemovePremiumForTesting)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                #endif
            }
        } else {
            VStack(spacing: 12) {
                Button(action: viewModel.onSubscribe) {
                    Text("Suscribirme")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.bgDark)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.accentPurple)
                        .cornerRadius(16)
                }
                Text("Activación de prueba — la suscripción real llega pronto.")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
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
