import SwiftUI

/// The retention step before the user reaches the App Store's subscription manager, mirroring
/// Android's `CancelSubscriptionSheet`.
///
/// Android uses a Material `ModalBottomSheet`; this is a plain `.sheet` with detents, which is
/// the same affordance on iOS. The exit is visually de-emphasised but never hidden or delayed —
/// burying it is a dark pattern, and both stores' rules say so.
struct CancelSubscriptionSheet: View {
    let onKeepPremium: () -> Void
    let onCancelAnyway: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("¿Seguro que quieres cancelar?")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.textPrimary)
                .padding(.top, 28)

            Text("Si cancelas, al terminar tu periodo actual vas a perder:")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 14) {
                lossRow(
                    icon: "infinity",
                    text: Text("Vuelves al límite de \(PremiumGate.freeHabitLimit) hábitos activos.")
                )
                lossRow(
                    icon: "nosign",
                    text: Text("Los anuncios vuelven al compartir frases.")
                )
                lossRow(
                    icon: "sparkles",
                    text: Text("Pokémon, Black Clover y los demás se bloquean otra vez.")
                )
            }
            .padding(.top, 24)

            // No date here on purpose: same as Android, the client is not told when the paid
            // period ends, so promising one would be a guess.
            Text("Tranquilo: conservas todo hasta el final del periodo que ya pagaste.")
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surface)
                .cornerRadius(14)
                .padding(.top, 24)

            Spacer(minLength: 24)

            Button(action: onKeepPremium) {
                Text("Seguir siendo premium")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.bgDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentPurple)
                    .cornerRadius(16)
            }

            Button(action: onCancelAnyway) {
                Text("Cancelar de todos modos")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bgDark.ignoresSafeArea())
    }

    private func lossRow(icon: String, text: Text) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.textSecondary)
                .frame(width: 22)
            text
                .font(.system(size: 14))
                .strikethrough()
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.leading)
                // Inside an HStack a Text gets one line and truncates; the themes row is long
                // enough in both languages to need two.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    Color.bgDark
        .sheet(isPresented: .constant(true)) {
            CancelSubscriptionSheet(onKeepPremium: {}, onCancelAnyway: {})
                .presentationDetents([.medium, .large])
        }
        .preferredColorScheme(.dark)
}
