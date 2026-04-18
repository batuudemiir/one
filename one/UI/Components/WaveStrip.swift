//
//  WaveStrip.swift
//  One - Günlük Mood
//

import SwiftUI

struct WaveStrip: View {
    let summary: MonthSummary
    @Binding var selectedWaveIdx: Int?
    
    var body: some View {
        GeometryReader { geo in
            let orderedDays = summary.orderedDays
            let barWidth = max(2, (geo.size.width - CGFloat(orderedDays.count)) / CGFloat(orderedDays.count))
            
            HStack(alignment: .center, spacing: 1) {
                ForEach(Array(orderedDays.enumerated()), id: \.offset) { idx, date in
                    if let date, let entry = summary.primaryEntry(for: date) {
                        // Filled day bar with mood color
                        if let mood = ONEMood(hex: entry.moodColorHex) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(mood.color
                                    .opacity(selectedWaveIdx == idx ? 1.0 : 0.72))
                                .frame(width: barWidth, height: mood.waveHeight)
                                .onTapGesture {
                                    selectedWaveIdx = idx
                                }
                        } else {
                            // Fallback for unknown mood colors
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: entry.moodColorHex)
                                    .opacity(selectedWaveIdx == idx ? 1.0 : 0.72))
                                .frame(width: barWidth, height: 12)
                                .onTapGesture {
                                    selectedWaveIdx = idx
                                }
                        }
                    } else {
                        // Empty day bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ONETokens.oneCreamMid.opacity(0.6))
                            .frame(width: barWidth, height: 4)
                    }
                }
            }
            .frame(maxHeight: 32, alignment: .center)
        }
        .frame(height: 32)
    }
}
