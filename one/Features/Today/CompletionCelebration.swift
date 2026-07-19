//
//  CompletionCelebration.swift
//  one
//
//  Günlük kayıt tamamlandığında oynayan sürpriz animasyonlar.
//  Her kayıtta 5 animasyondan biri sırayla seçilir.
//

import SwiftUI

// MARK: - Animation Type

enum CelebrationType: Int, CaseIterable {
    case rippleRings   // genişleyen halkalar
    case floatingNotes // yükselen nota bulutları
    case dotBurst      // renk patlaması
    case starSparkle   // yıldız parıltıları
    case inkWash       // mürekkep dalgası

    /// Sıralı (ama karışık görünen) seçim — aynı animasyon art arda gelmiyor.
    static func pick() -> CelebrationType {
        let key = "celebrationIndex_v1"
        let n = UserDefaults.standard.integer(forKey: key)
        // Psikolojik karışıklık için sıra: rings → burst → notes → wash → sparkle
        let order: [CelebrationType] = [.rippleRings, .dotBurst, .floatingNotes, .inkWash, .starSparkle]
        let chosen = order[n % order.count]
        UserDefaults.standard.set((n + 1) % order.count, forKey: key)
        return chosen
    }
}

// MARK: - Container

struct CompletionCelebrationView: View {
    let type: CelebrationType
    let moodColor: Color
    let onFinished: () -> Void

    var body: some View {
        ZStack {
            switch type {
            case .rippleRings:   RippleRingsAnimation(moodColor: moodColor)
            case .floatingNotes: FloatingNotesAnimation(moodColor: moodColor)
            case .dotBurst:      DotBurstAnimation(moodColor: moodColor)
            case .starSparkle:   StarSparkleAnimation(moodColor: moodColor)
            case .inkWash:       InkWashAnimation(moodColor: moodColor)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { onFinished() }
        }
    }
}

// MARK: - 1. Ripple Rings
// Ruh hali renginde 3 halka merkezdekinden dışa yayılır ve söner.

private struct RippleRingsAnimation: View {
    let moodColor: Color
    @State private var s1: CGFloat = 0.15; @State private var o1: Double = 0.7
    @State private var s2: CGFloat = 0.15; @State private var o2: Double = 0.6
    @State private var s3: CGFloat = 0.15; @State private var o3: Double = 0.5

    var body: some View {
        ZStack {
            ring(scale: s1, opacity: o1)
            ring(scale: s2, opacity: o2)
            ring(scale: s3, opacity: o3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            animateRing(delay: 0.00) { s1 = 3.8; o1 = 0 }
            animateRing(delay: 0.28) { s2 = 4.2; o2 = 0 }
            animateRing(delay: 0.56) { s3 = 4.6; o3 = 0 }
        }
    }

    private func ring(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .strokeBorder(moodColor, lineWidth: 1.8)
            .frame(width: 110, height: 110)
            .scaleEffect(scale)
            .opacity(opacity)
    }

    private func animateRing(delay: Double, update: @escaping () -> Void) {
        withAnimation(.easeOut(duration: 1.5).delay(delay)) { update() }
    }
}

// MARK: - 2. Floating Notes
// 6 müzik notası aşağıdan yukarı süzülür ve kaybolur.

private struct FloatingNotesAnimation: View {
    let moodColor: Color

    private struct NoteItem: Identifiable {
        let id = UUID()
        let glyph: String
        let x: CGFloat     // -150…+150 (center-relative)
        let delay: Double
        let rotation: Double
        let size: CGFloat
    }

    private let notes: [NoteItem] = [
        NoteItem(glyph: "♪", x: -110, delay: 0.00, rotation: -12, size: 22),
        NoteItem(glyph: "♫", x:  -50, delay: 0.08, rotation:   8, size: 18),
        NoteItem(glyph: "♩", x:   20, delay: 0.14, rotation: -6,  size: 20),
        NoteItem(glyph: "♬", x:   90, delay: 0.05, rotation:  14, size: 16),
        NoteItem(glyph: "♪", x: -130, delay: 0.20, rotation:  -9, size: 14),
        NoteItem(glyph: "♫", x:   60, delay: 0.18, rotation:   5, size: 24),
    ]

    @State private var risen  = false
    @State private var faded  = false

    var body: some View {
        GeometryReader { geo in
            let cy = geo.size.height * 0.6  // başlangıç Y (biraz altı)
            let cx = geo.size.width  / 2

            ZStack {
                ForEach(notes) { note in
                    Text(note.glyph)
                        .font(.system(size: note.size, weight: .medium))
                        .foregroundColor(moodColor.opacity(0.85))
                        .rotationEffect(.degrees(risen ? note.rotation : 0))
                        .offset(
                            x: cx + note.x - geo.size.width / 2,
                            y: risen ? cy - 220 : cy
                        )
                        .opacity(faded ? 0 : 1)
                        .animation(
                            .spring(response: 0.9, dampingFraction: 0.78).delay(note.delay),
                            value: risen
                        )
                        .animation(
                            .easeIn(duration: 0.5).delay(note.delay + 0.9),
                            value: faded
                        )
                }
            }
        }
        .onAppear {
            risen = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { faded = true }
        }
    }
}

// MARK: - 3. Dot Burst
// 12 renkli nokta merkezdeki patlamadan dışa saçılır.

private struct DotBurstAnimation: View {
    let moodColor: Color

    private struct Dot: Identifiable {
        let id = UUID()
        let angle: Double   // derece
        let distance: CGFloat
        let size: CGFloat
        let isAccent: Bool  // true = beyaz, false = mood rengi
    }

    private let dots: [Dot] = (0..<12).map { i in
        Dot(
            angle: Double(i) * 30.0,
            distance: [88, 110, 96, 118, 92, 105, 82, 122, 100, 87, 114, 95][i],
            size: [6, 5, 7, 5, 6, 8, 5, 6, 7, 5, 6, 8][i],
            isAccent: i % 4 == 0
        )
    }

    @State private var expanded = false
    @State private var visible  = true

    var body: some View {
        ZStack {
            ForEach(dots) { dot in
                let rad = dot.angle * .pi / 180
                Circle()
                    .fill(dot.isAccent ? Color.white : moodColor)
                    .frame(width: dot.size, height: dot.size)
                    .offset(
                        x: expanded ? dot.distance * CGFloat(cos(rad)) : 0,
                        y: expanded ? dot.distance * CGFloat(sin(rad)) : 0
                    )
                    .opacity(visible ? 1 : 0)
                    .scaleEffect(expanded ? 1 : 0.3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { expanded = true }
            withAnimation(.easeOut(duration: 0.45).delay(0.65)) { visible = false }
        }
    }
}

// MARK: - 4. Star Sparkle
// 8 yıldız ekranda belirir ve sönümlenir.

private struct StarSparkleAnimation: View {
    let moodColor: Color

    private struct Star: Identifiable {
        let id = UUID()
        let x: CGFloat   // ekran genişliğine oranı (0…1)
        let y: CGFloat   // ekran yüksekliğine oranı (0…1)
        let size: CGFloat
        let delay: Double
        let rotation: Double
    }

    private let stars: [Star] = [
        Star(x: 0.12, y: 0.22, size: 18, delay: 0.00, rotation:  0),
        Star(x: 0.80, y: 0.15, size: 14, delay: 0.12, rotation: 45),
        Star(x: 0.35, y: 0.72, size: 22, delay: 0.06, rotation: 20),
        Star(x: 0.68, y: 0.60, size: 16, delay: 0.18, rotation: -30),
        Star(x: 0.90, y: 0.42, size: 12, delay: 0.09, rotation: 60),
        Star(x: 0.20, y: 0.48, size: 20, delay: 0.15, rotation: -15),
        Star(x: 0.55, y: 0.28, size: 15, delay: 0.03, rotation: 30),
        Star(x: 0.78, y: 0.80, size: 17, delay: 0.21, rotation: -45),
    ]

    @State private var appeared = false
    @State private var peaked   = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(stars) { star in
                    Image(systemName: "sparkle")
                        .font(.system(size: star.size))
                        .foregroundColor(moodColor.opacity(0.9))
                        .rotationEffect(.degrees(star.rotation))
                        .position(x: geo.size.width * star.x, y: geo.size.height * star.y)
                        .scaleEffect(appeared ? (peaked ? 0 : 1) : 0)
                        .opacity(appeared ? (peaked ? 0 : 1) : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.6).delay(star.delay),
                            value: appeared
                        )
                        .animation(
                            .easeIn(duration: 0.4).delay(star.delay + 0.55),
                            value: peaked
                        )
                }
            }
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { peaked = true }
        }
    }
}

// MARK: - 5. Ink Wash
// Mood rengi tüm ekrana yumuşakça yayılır ve söner — Japon mürekkep etkisi.

private struct InkWashAnimation: View {
    let moodColor: Color
    @State private var scale:   CGFloat = 0.05
    @State private var opacity: Double  = 0

    var body: some View {
        GeometryReader { geo in
            let diag = max(geo.size.width, geo.size.height) * 2.2
            Circle()
                .fill(moodColor)
                .frame(width: diag, height: diag)
                .scaleEffect(scale)
                .opacity(opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                scale   = 1.0
                opacity = 0.13
            }
            withAnimation(.easeIn(duration: 0.6).delay(0.75)) {
                opacity = 0
            }
        }
    }
}
