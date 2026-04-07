import SwiftUI

struct WidgetTutorialView: View {
    @State private var currentStep = 0

    private let steps: [(title: String, description: String, icon: String)] = [
        (
            "Mantén pulsado el escritorio",
            "Toca y mantén pulsado cualquier zona vacía del escritorio hasta que los iconos empiecen a moverse.",
            "hand.tap.fill"
        ),
        (
            "Toca el botón +",
            "En la esquina superior izquierda aparece un botón "+" para añadir widgets.",
            "plus.circle.fill"
        ),
        (
            "Busca Quote Anime",
            "Escribe Quote en el buscador y selecciona el widget de Quote Anime.",
            "magnifyingglass"
        ),
        (
            "Elige el tamaño y añade",
            "Desliza para elegir el tamaño del widget y pulsa Añadir widget.",
            "checkmark.circle.fill"
        ),
    ]

    var body: some View {
        ZStack {
            Color.bgDark.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentStep) {
                    ForEach(steps.indices, id: \.self) { index in
                        stepPage(step: steps[index], index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                // Dot indicators
                HStack(spacing: 8) {
                    ForEach(steps.indices, id: \.self) { index in
                        Capsule()
                            .fill(currentStep == index ? Color.accentPurple : Color.outline)
                            .frame(width: currentStep == index ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 16)

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Anterior") { currentStep -= 1 }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.surface)
                            .cornerRadius(12)
                    }

                    Button(currentStep < steps.count - 1 ? "Siguiente" : "Entendido") {
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                        }
                        // "Entendido" — navigation back is handled by NavigationStack
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.bgDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.accentPurple)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Añadir widget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func stepPage(step: (title: String, description: String, icon: String), index: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Paso \(index + 1) de \(steps.count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentPurple)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.accentPurple.opacity(0.15))
                .cornerRadius(20)

            Image(systemName: step.icon)
                .font(.system(size: 64))
                .foregroundColor(.accentPurple)

            VStack(spacing: 10) {
                Text(step.title)
                    .font(.quoteSerif(size: 22))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}
