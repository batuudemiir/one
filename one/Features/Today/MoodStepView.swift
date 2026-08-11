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
                    .foregroundColor(V3Tokens.ink)
                    .padding(.bottom, 2)

                // Kadran kalan dikey boşluğa göre ölçekleniyor — sabit
                // 290pt küçük ekranlarda taşıyor, buton ekran dışında
                // kalıyordu.
                GeometryReader { geo in
                    MoodDial(
                        selection: $selectedMood,
                        maxDiameter: min(geo.size.width - 32, geo.size.height)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(maxHeight: .infinity)

                Button {
                    guard let mood = selectedMood else { return }
                    coordinator.draft.mood = mood
                    coordinator.next()
                } label: {
                    Text("devam")
                        .bodySMMedium()
                        .foregroundColor(ONEBrand.bone)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule(style: .continuous).fill(V3Tokens.ink))
                }
                .disabled(selectedMood == nil)
                .opacity(selectedMood == nil ? 0.28 : 1)
                .animation(.easeOut(duration: 0.18), value: selectedMood != nil)
                .padding(.horizontal, ONETokens.spacingXL)
                .padding(.bottom, ONETokens.spacingLG)
            }
            // Üst çubuk artık düzenin içinde; buradaki büyük üst boşluk
            // onun altına ikinci bir boşluk ekliyordu.
            .padding(.top, ONETokens.spacingMD)
        }
    }
}
