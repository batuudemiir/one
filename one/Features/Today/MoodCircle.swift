//
//  MoodCircle.swift
//  one
//

import SwiftUI

struct MoodCircle: View {
    let mood: ONEMood
    let distance: Int
    let isSelected: Bool

    private var circleSize: CGFloat {
        switch distance {
        case 0: return 80
        case 1: return 63
        case 2: return 51
        case 3: return 40
        default: return 32
        }
    }

    private var alpha: Double {
        switch distance {
        case 0: return 1.0
        case 1: return 0.78
        case 2: return 0.56
        case 3: return 0.36
        default: return 0.2
        }
    }

    private var cornerRadius: CGFloat { circleSize * 0.36 }

    var body: some View {
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.82), lineWidth: 2)
                    .frame(width: circleSize + 10, height: circleSize + 10)
            }
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(mood.color)
                .frame(width: circleSize, height: circleSize)
                .opacity(alpha)
                .shadow(
                    color: distance == 0 ? mood.color.opacity(0.35) : .clear,
                    radius: 12, y: 5
                )
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: circleSize)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isSelected)
    }
}
