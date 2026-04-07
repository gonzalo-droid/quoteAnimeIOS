import SwiftUI

struct SplashView: View {
    let isOnboardingCompleted: Bool
    let onComplete: (Bool) -> Void   // passes `isFirstTime`

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.85

    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "quote.bubble.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(Color.accentPurple)

                Text("Quote Anime")
                    .font(.quoteSerif(size: 28))
                    .foregroundColor(.textPrimary)
                    .kerning(1.5)
            }
            .opacity(opacity)
            .scaleEffect(scale)
        }
        .onAppear { animate() }
    }

    private func animate() {
        withAnimation(.easeOut(duration: 0.55)) {
            opacity = 1
            scale   = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            onComplete(!isOnboardingCompleted)
        }
    }
}
