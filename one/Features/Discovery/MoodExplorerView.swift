//
//  MoodExplorerView.swift
//  one
//
//  Keşfet sekmesi — Mood explorer yatay chip'ler
//  Kullanıcılar farklı mood'ların etkinlik/şarkılarını keşfedebilir
//

import SwiftUI

struct MoodExplorerView: View {
    let selectedMood: ONEMood?
    let currentMoodLabel: String?
    let onSelect: (ONEMood) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("discover.explore", comment: ""))
                .monoBase(tracking: 2)
                .foregroundColor(ONETokens.oneAsh)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ONEMood.allCases) { mood in
                        let isSelected = selectedMood == mood
                        let isCurrentMood = currentMoodLabel == mood.label

                        Button(action: { onSelect(mood) }) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(mood.color)
                                    .frame(width: 8, height: 8)

                                Text(mood.label)
                                    .monoSM(tracking: 0.4)
                                    .foregroundColor(
                                        isSelected ? .white :
                                        isCurrentMood ? mood.color :
                                        ONETokens.oneCharcoal
                                    )

                                if isCurrentMood {
                                    Text(NSLocalizedString("discover.today", comment: ""))
                                        .monoMicro(tracking: 0.6)
                                        .foregroundColor(
                                            isSelected ? .white.opacity(0.7) : mood.color.opacity(0.7)
                                        )
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? mood.color : ONETokens.onePaper)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isSelected ? Color.clear :
                                        isCurrentMood ? mood.color.opacity(0.3) :
                                        ONETokens.oneSilver,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}
