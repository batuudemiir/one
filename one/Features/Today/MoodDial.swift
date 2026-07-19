//
//  MoodDial.swift
//  one
//
//  Prototipteki `.dial` — 12 mood bir çember üzerinde, ortada canlı etiket.
//

import SwiftUI

/// Dairesel mood seçici.
///
/// Liste yerine çember olmasının sebebi ritüelin kendisi: 12 mood arasında
/// hiyerarşi yok, hepsi eşit uzaklıkta. Dikey bir liste ilk sıradakini
/// ayrıcalıklı kılıyor ve seçimi "tarama"ya çeviriyordu; çember hepsini
/// tek bakışta, eşit ağırlıkta gösteriyor.
struct MoodDial: View {
    @Binding var selection: ONEMood?

    /// Prototip geometrisi: 290pt kadran, 113pt yarıçap, 56pt swatch,
    /// 120pt merkez. Oranlar bozulmasın diye tek yerde.
    private let dialSize: CGFloat = 290
    private let radius: CGFloat = 113
    private let swatchSize: CGFloat = 56
    private let coreSize: CGFloat = 120

    private var moods: [ONEMood] { ONEMood.allCases }

    var body: some View {
        ZStack {
            ForEach(Array(moods.enumerated()), id: \.element) { index, mood in
                swatch(mood)
                    .offset(offset(for: index))
            }

            core
        }
        .frame(width: dialSize, height: dialSize)
        .accessibilityElement(children: .contain)
    }

    // MARK: Swatch

    private func swatch(_ mood: ONEMood) -> some View {
        let isSelected = selection == mood

        return Button {
            // Seçim haptiği — `saveRitual` kaydetme anına ait, her dokunuşta
            // çalınırsa o anın ağırlığını harcar.
            ONEHaptics.feelingSelected()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
                selection = mood
            }
        } label: {
            Circle()
                .fill(mood.color)
                .frame(width: swatchSize, height: swatchSize)
                .overlay {
                    // Prototip: seçiliyken krem boşluk + mürekkep halka.
                    if isSelected {
                        Circle()
                            .stroke(ONETokens.oneCream, lineWidth: 3)
                            .overlay(
                                Circle()
                                    .stroke(ONETokens.oneInk, lineWidth: 2)
                                    .padding(-2.5)
                            )
                            .padding(-1.5)
                    }
                }
                .scaleEffect(isSelected ? 1.16 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Tepeden başlayıp saat yönünde: `-π/2` kaydırma bunun için.
    private func offset(for index: Int) -> CGSize {
        let angle = (Double(index) / Double(moods.count)) * 2 * .pi - .pi / 2
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }

    // MARK: Core

    /// Merkez seçimi yansıtır — swatch'a dokununca etiket burada beliriyor,
    /// böylece kullanıcı parmağını kaldırmadan ne seçtiğini görüyor.
    private var core: some View {
        Circle()
            .fill(ONETokens.oneCream)
            .frame(width: coreSize, height: coreSize)
            .overlay {
                Group {
                    if let mood = selection {
                        VStack(spacing: 3) {
                            Text(mood.label)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(ONETokens.oneInk)
                            Text(mood.meaning)
                                .font(.system(size: 11))
                                .foregroundColor(ONETokens.oneAsh)
                                .multilineTextAlignment(.center)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    } else {
                        Text("bir renge\ndokun")
                            .font(.system(size: 12))
                            .foregroundColor(ONETokens.oneStone)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 8)
            }
            .animation(.easeOut(duration: 0.2), value: selection)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview {
    struct Wrapper: View {
        @State private var mood: ONEMood?
        var body: some View {
            ZStack {
                ONETokens.oneCream.ignoresSafeArea()
                MoodDial(selection: $mood)
            }
        }
    }
    return Wrapper()
}
