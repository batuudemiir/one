//
//  ProgressDots.swift
//  one
//

import SwiftUI

struct RitualProgressDots: View {
    let current: Int  // 0-indexed
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: 5, height: 5)
                    .animation(.easeOut(duration: 0.2), value: current)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adım \(current + 1) / \(total)")
    }

    private func dotColor(for index: Int) -> Color {
        if index < current { return V3Tokens.faintText }
        if index == current { return ONETokens.oneVoid }
        return Color.black.opacity(0.12)
    }
}
