//
//  WeeklyProgressDots.swift
//  one
//
//  This week's logged entries shown as mood-colored dots.
//  Design rule: only filled/logged days are shown — no empty
//  placeholders, no visual guilt for unlogged days.
//

import SwiftUI

struct WeeklyProgressDots: View {
    let entries: [(date: Date, moodColorHex: String)]

    private var displayedCount: Int { min(entries.count, 7) }

    var body: some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 6) {
                ForEach(Array(entries.prefix(7).enumerated()), id: \.offset) { _, item in
                    Circle()
                        .fill(Color(hex: item.moodColorHex))
                        .frame(width: 8, height: 8)
                }
                Text("bu hafta \(displayedCount) gün")
                    .font(.custom("GeistMono-Regular", size: 10))
                    .tracking(0.6)
                    .foregroundColor(V3Tokens.faintText)
            }
        }
    }
}
