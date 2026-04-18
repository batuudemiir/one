//
//  TodaySongMiniCard.swift
//  one
//
//  Keşfet sekmesi — Bugünün şarkısı mini kartı
//

import SwiftUI

struct TodaySongMiniCard: View {
    let entry: DailyEntry

    var body: some View {
        HStack(spacing: 12) {
            // Mood color bar
            RoundedRectangle(cornerRadius: 3)
                .fill(entry.moodColor)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("discover.todaySong", comment: ""))
                    .monoMicro(tracking: 1.2)
                    .foregroundColor(ONETokens.oneAsh)

                Text(entry.songName)
                    .bodySMMedium()
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.artistName)
                    .monoSM(tracking: 0.4)
                    .foregroundColor(ONETokens.oneAsh)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.moodColor)
                        .frame(width: 6, height: 6)
                    Text(entry.moodLabel)
                        .monoLabel(tracking: 0.6)
                        .foregroundColor(entry.moodColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                .fill(ONETokens.onePaper)
                .overlay(
                    RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                        .stroke(entry.moodColor.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
