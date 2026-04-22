import SwiftUI

struct SplashView: View {
    let isOnboardingCompleted: Bool
    let onComplete: (Bool) -> Void   // passes `isFirstTime`

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.85

    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()

            VStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

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

#Preview {
    SplashView(isOnboardingCompleted: true, onComplete: { _ in })
}
