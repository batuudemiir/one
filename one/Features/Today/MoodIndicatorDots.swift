//
//  MoodIndicatorDots.swift
//  one
//

import SwiftUI

struct MoodIndicatorDots: View {
    let current: Int  // 0–11

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<12, id: \.self) { i in
                if i == current {
                    Capsule()
                        .fill(ONETokens.oneVoid)
                        .frame(width: 16, height: 4)
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: current)
    }
}
