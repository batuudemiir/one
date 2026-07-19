//
//  MoodStepView.swift
//  one
//

import SwiftUI

struct MoodStepView: View {
    @ObservedObject var coordinator: TodayCoordinator
    @State private var selectedMood: ONEMood?

    var body: some View {
        ZStack {
            // Seçilen rengin ekrana çok hafif vurması — prototipte de kadran
            // seçildikçe ortam ısınıyor.
            if let mood = selectedMood {
                VStack {
                    LinearGradient(
                        colors: [mood.color.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 220)
                    Spacer()
                }
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.35), value: selectedMood)
            }

            VStack(spacing: 0) {
                // Prototip: tek satır, ortalanmış soru. Alt açıklama yok —
                // kadranın ortası zaten "bir renge dokun" diyor.
                Text("bugün ne renktin?")
                    .displayMD()
                    .multilineTextAlignment(.center)
                    .foregroundColor(ONETokens.oneInk)
                    .padding(.bottom, 2)

                // Kadran dikey boşluğun ortasına oturur.
                MoodDial(selection: $selectedMood)
                    .frame(maxHeight: .infinity)

                Button {
                    guard let mood = selectedMood else { return }
                    coordinator.draft.mood = mood
                    coordinator.next()
                } label: {
                    Text("devam")
                        .bodySMMedium()
                        .foregroundColor(ONETokens.oneCream)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule(style: .continuous).fill(ONETokens.oneInk))
                }
                .disabled(selectedMood == nil)
                .opacity(selectedMood == nil ? 0.28 : 1)
                .animation(.easeOut(duration: 0.18), value: selectedMood != nil)
                .padding(.horizontal, ONETokens.spacingXL)
                .padding(.bottom, ONETokens.spacingXL3)
            }
            .padding(.top, ONETokens.spacingXL3)
        }
    }
}
