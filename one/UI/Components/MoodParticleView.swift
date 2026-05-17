//
//  MoodParticleView.swift
//  one
//
//  Mood Bloom reward animation — floating particles layer.
//  Triggered once per ritual save; respects Reduce Motion.
//

import SwiftUI

private struct ParticleConfig: Identifiable {
    let id = UUID()
    let xOffset: CGFloat
    let size: CGFloat
    let delay: Double
    let riseHeight: CGFloat
    let isLight: Bool

    static func generate(count: Int = 8) -> [ParticleConfig] {
        (0..<count).map { i in
            ParticleConfig(
                xOffset: CGFloat.random(in: -35...35),
                size: CGFloat.random(in: 4...8),
                delay: Double(i) * 0.05,
                riseHeight: CGFloat.random(in: 70...130),
                isLight: i % 5 >= 3   // 40% white, 60% mood pastel
            )
        }
    }
}

struct MoodParticleView: View {
    let mood: ONEMood
    @Binding var triggered: Bool

    @State private var particles: [ParticleConfig] = []
    @State private var risen = false
    @State private var faded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(p.isLight ? Color.white.opacity(0.7) : mood.color.opacity(0.45))
                        .frame(width: p.size, height: p.size)
                        .offset(
                            x: risen ? p.xOffset : 0,
                            y: risen ? -p.riseHeight : 0
                        )
                        .opacity(faded ? 0 : (risen ? 0.85 : 0))
                        .animation(.easeOut(duration: 1.0).delay(p.delay), value: risen)
                        .animation(.easeIn(duration: 0.5).delay(p.delay + 0.6), value: faded)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                particles = ParticleConfig.generate()
            }
            .onChange(of: triggered) { _, newVal in
                if newVal {
                    risen = false; faded = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                        withAnimation { risen = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                            withAnimation { faded = true }
                        }
                    }
                } else {
                    risen = false; faded = false
                }
            }
        }
    }
}
