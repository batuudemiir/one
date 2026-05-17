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
            .accessibilityElement(children: .combine)
            .accessibilityLabel(combinedLabel)
        }
        .frame(height: 3)
    }

    /// Combined VoiceOver label for the mood distribution strip.
    ///
    /// - Requirement 13.1: rendered with `accessibilityElement(children: .combine)` at the container.
    /// - Requirement 13.2: lists each mood segment in descending proportion order.
    /// - Requirement 13.3: announces an empty-state label when no data exists
    ///   (filledDays == 0) or when every segment rounds to 0%.
    /// - Requirement 13.4: percentages rounded to the nearest integer (half-up).
    /// - Requirement 13.5: duplicate mood labels are consolidated into a single percentage.
    ///
    /// Exposed with `internal` access so unit tests in `MoodBarStripLabelTests`
    /// can reach it via `@testable import`.
    var combinedLabel: String {
        guard filledDays > 0 else {
            return NSLocalizedString("moodbarstrip.empty", comment: "Aylık mood dağılımı: kayıt yok")
        }

        let items = moodDistribution
            .compactMap { item -> (label: String, pct: Int)? in
                guard let mood = ONEMood(hex: item.color) else { return nil }
                let pct = Int((Double(item.count) / Double(filledDays) * 100).rounded())
                return (mood.label, pct)
            }
            .sorted { $0.pct > $1.pct }
            .reduce(into: [(label: String, pct: Int)]()) { acc, next in
                if let idx = acc.firstIndex(where: { $0.label == next.label }) {
                    acc[idx].pct += next.pct
                } else {
                    acc.append(next)
                }
            }

        guard items.contains(where: { $0.pct > 0 }) else {
            return NSLocalizedString("moodbarstrip.empty", comment: "Aylık mood dağılımı: kayıt yok")
        }

        let parts = items
            .map { "%\($0.pct) \($0.label)" }
            .joined(separator: ", ")
        return String(
            format: NSLocalizedString("moodbarstrip.summary", comment: "Aylık mood dağılımı: %@"),
            parts
        )
    }
}
