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

                Text("Desbloqueá todo el potencial de tu rutina.")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.horizontal, 24)

                VStack(spacing: 20) {
                    benefitRow(
                        icon: "infinity",
                        title: "Hábitos ilimitados",
                        body: "Sin el límite de 3 hábitos activos — creá todos los que necesites."
                    )
                    benefitRow(
                        icon: "nosign",
                        title: "Sin anuncios",
                        body: "Compartí tus frases favoritas sin interrupciones publicitarias."
                    )
                    benefitRow(
                        icon: "sparkles",
                        title: "Temas exclusivos",
                        body: "Accedé a colecciones temáticas exclusivas, como Pokémon y Black Clover."
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
            Spacer()
        }
        .frame(height: 52)
    }

    @ViewBuilder
    private var ctaSection: some View {
        if viewModel.uiState.isPremium {
            VStack(spacing: 8) {
                Text("✨ Ya sos premium")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Button("Quitar premium (solo pruebas)", action: viewModel.onRemovePremiumForTesting)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
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

    private func benefitRow(icon: String, title: String, body: String) -> some View {
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
    }
}
