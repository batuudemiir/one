//
//  MoodBarStrip.swift
//  One - Günlük Mood
//

import SwiftUI

struct MoodBarStrip: View {
    let moodDistribution: [(color: String, count: Int)]
    let filledDays: Int
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(moodDistribution, id: \.color) { item in
                    let proportionalWidth = geo.size.width * CGFloat(item.count) / CGFloat(filledDays)
                    let finalWidth = max(proportionalWidth, 3)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: item.color).opacity(0.7))
                        .frame(width: finalWidth, height: 3)
                }
            }
        }
        .frame(height: 3)
    }
}
