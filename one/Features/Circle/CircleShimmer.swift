//
//  CircleShimmer.swift
//  one
//
//  Light Serenity shimmer modifier for Circle skeleton cards.
//  Reduce Motion respected.
//  Extracted from CircleView.swift in Faz 3.1 (2026-04-26).
//

import SwiftUI

private struct CircleShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        V3Tokens.surface.opacity(0.4),
                        Color.clear
                    ]),
                    startPoint: .init(x: phase - 0.5, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusPanel))
            )
            .onAppear {
                // Reduce Motion: shimmer atlanır
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmeringCircle() -> some View {
        modifier(CircleShimmerModifier())
    }
}
