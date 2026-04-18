//
//  SaveRitualParticles.swift
//  one
//
//  Design System - Save Ritual Particle Effects
//  Canvas + TimelineView tabanlı 60fps mood'a özgü parçacık efektleri
//

import SwiftUI

// MARK: - Particle Model

struct RParticle {
    let ox: CGFloat       // başlangıç X ofseti (center'dan)
    let oy: CGFloat       // başlangıç Y ofseti (center'dan)
    let vx: CGFloat       // X hızı (pts/s)
    let vy: CGFloat       // Y hızı (pts/s, yukarı negatif)
    let size: CGFloat     // parçacık boyutu
    let delay: Double     // başlama gecikmesi (s)
    let maxLife: Double   // yaşam süresi (s)
    let rotation0: Double // başlangıç rotasyonu (derece)
    let rotSpeed: Double  // dönme hızı (derece/s)
}

// MARK: - SaveRitualParticles View

struct SaveRitualParticles: View {
    let mood: ONEMood
    let color: Color

    @State private var startDate = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particles: [RParticle]

    init(mood: ONEMood, color: Color) {
        self.mood = mood
        self.color = color
        self.particles = SaveRitualParticles.makeParticles(for: mood)
    }

    var body: some View {
        // Reduce Motion: 60fps parçacık animasyonu yerine statik sparkle ikonu
        if reduceMotion {
            Image(systemName: mood.icon)
                .font(.system(size: 32))
                .foregroundColor(color.opacity(0.5))
                .allowsHitTesting(false)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                Canvas { ctx, size in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    drawParticles(ctx: &ctx, center: center, elapsed: elapsed)
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }

    // MARK: - Particle Factory

    private static func makeParticles(for mood: ONEMood) -> [RParticle] {
        var result: [RParticle] = []

        switch mood {

        case .atesli:
            // 50 ember — radyal dağılım, aşağı gravite
            for i in 0..<50 {
                let angle = Double(i) * (2 * .pi / 50) + Double(i % 7) * 0.18
                let speed = 180.0 + Double(i % 5) * 55.0
                result.append(RParticle(
                    ox: 0, oy: 0,
                    vx: CGFloat(cos(angle) * speed),
                    vy: CGFloat(sin(angle) * speed),
                    size: 3 + CGFloat(i % 4),
                    delay: Double(i % 8) * 0.018,
                    maxLife: 0.9 + Double(i % 3) * 0.15,
                    rotation0: angle * 180 / .pi,
                    rotSpeed: 0
                ))
            }

        case .enerjik:
            // 45 konfeti karesi — yüksek rotSpeed
            for i in 0..<45 {
                let angle = Double(i) * (2 * .pi / 45) + Double(i % 5) * 0.22
                let speed = 160.0 + Double(i % 6) * 45.0
                result.append(RParticle(
                    ox: 0, oy: 0,
                    vx: CGFloat(cos(angle) * speed),
                    vy: CGFloat(sin(angle) * speed),
                    size: 5 + CGFloat(i % 5),
                    delay: Double(i % 9) * 0.015,
                    maxLife: 1.0 + Double(i % 4) * 0.12,
                    rotation0: Double(i) * 37.0,
                    rotSpeed: 180.0 + Double(i % 5) * 90.0
                ))
            }

        case .isikli:
            // 28 yıldız — altın açı dağılımı, yavaş drift
            let goldenAngle = 2.39996 // radyan
            for i in 0..<28 {
                let angle = Double(i) * goldenAngle
                let speed = 80.0 + Double(i % 4) * 30.0
                result.append(RParticle(
                    ox: 0, oy: 0,
                    vx: CGFloat(cos(angle) * speed),
                    vy: CGFloat(sin(angle) * speed),
                    size: 6 + CGFloat(i % 4),
                    delay: Double(i % 6) * 0.025,
                    maxLife: 1.2 + Double(i % 3) * 0.20,
                    rotation0: Double(i) * 22.5,
                    rotSpeed: 15.0
                ))
            }

        case .sakin:
            // 20 kabarcık — yukarı yüzen, çok yavaş
            for i in 0..<20 {
                let xSpread = CGFloat(i % 7) * 22.0 - 66.0
                let speed = 55.0 + Double(i % 4) * 18.0
                result.append(RParticle(
                    ox: xSpread, oy: 0,
                    vx: 0,
                    vy: CGFloat(-speed),
                    size: 5 + CGFloat(i % 5),
                    delay: Double(i % 6) * 0.055,
                    maxLife: 1.4 + Double(i % 3) * 0.25,
                    rotation0: 0,
                    rotSpeed: 0
                ))
            }

        case .derin:
            // 18 damla — dışa yay hareketi
            for i in 0..<18 {
                let angle = Double(i) * (2 * .pi / 18)
                let speed = 120.0 + Double(i % 3) * 40.0
                result.append(RParticle(
                    ox: 0, oy: 0,
                    vx: CGFloat(cos(angle) * speed),
                    vy: CGFloat(sin(angle) * speed),
                    size: 4 + CGFloat(i % 3),
                    delay: Double(i % 5) * 0.030,
                    maxLife: 1.0 + Double(i % 3) * 0.18,
                    rotation0: 0,
                    rotSpeed: 0
                ))
            }

        case .gizemli:
            // 32 toz noktası — sinüzoidal yatay drift
            for i in 0..<32 {
                let angle = Double(i) * (2 * .pi / 32) + Double(i % 5) * 0.14
                let speed = 40.0 + Double(i % 6) * 18.0
                result.append(RParticle(
                    ox: CGFloat(cos(angle) * 30),
                    oy: CGFloat(sin(angle) * 30),
                    vx: CGFloat(cos(angle) * speed),
                    vy: CGFloat(sin(angle) * speed * 0.3),
                    size: 2,
                    delay: Double(i % 8) * 0.028,
                    maxLife: 1.5 + Double(i % 4) * 0.20,
                    rotation0: 0,
                    rotSpeed: 0
                ))
            }

        case .taze:
            // 24 yaprak — yukarı yüzen, hafif sağa-sola
            for i in 0..<24 {
                let xSpread = CGFloat(i % 8) * 18.0 - 63.0
                let speed = 70.0 + Double(i % 4) * 22.0
                result.append(RParticle(
                    ox: xSpread, oy: 0,
                    vx: CGFloat(Double(i % 3 - 1) * 15.0),
                    vy: CGFloat(-speed),
                    size: 4 + CGFloat(i % 4),
                    delay: Double(i % 6) * 0.040,
                    maxLife: 1.2 + Double(i % 3) * 0.22,
                    rotation0: Double(i) * 45.0,
                    rotSpeed: 30.0
                ))
            }

        case .ozgur:
            // 22 nokta — geniş radyal yayılım, hafif hız
            for i in 0..<22 {
                let angle = Double(i) * (2 * .pi / 22)
                let speed = 95.0 + Double(i % 4) * 35.0
                result.append(RParticle(
                    ox: 0, oy: 0,
                    vx: CGFloat(cos(angle) * speed),
                    vy: CGFloat(sin(angle) * speed * 0.7),
                    size: 3 + CGFloat(i % 3),
                    delay: Double(i % 6) * 0.030,
                    maxLife: 1.3 + Double(i % 3) * 0.20,
                    rotation0: 0,
                    rotSpeed: 0
                ))
            }

        case .nostaljik:
            // 16 damla — yavaş aşağı düşen, hafif drift
            for i in 0..<16 {
                let xSpread = CGFloat(i % 5) * 28.0 - 56.0
                result.append(RParticle(
                    ox: xSpread, oy: 0,
                    vx: CGFloat(Double(i % 3 - 1) * 10.0),
                    vy: CGFloat(60.0 + Double(i % 3) * 20.0),
                    size: 3 + CGFloat(i % 3),
                    delay: Double(i % 5) * 0.060,
                    maxLife: 1.6 + Double(i % 3) * 0.25,
                    rotation0: 0,
                    rotSpeed: 0
                ))
            }

        case .hassas:
            // 20 küçük daire — yavaş dağılım, nazik
            for i in 0..<20 {
                let angle = Double(i) * (2 * .pi / 20)
                let speed = 50.0 + Double(i % 4) * 20.0
                result.append(RParticle(
                    ox: 0, oy: 0,
                    vx: CGFloat(cos(angle) * speed),
                    vy: CGFloat(sin(angle) * speed),
                    size: 3 + CGFloat(i % 3),
                    delay: Double(i % 6) * 0.040,
                    maxLife: 1.4 + Double(i % 3) * 0.25,
                    rotation0: 0,
                    rotSpeed: 0
                ))
            }

        case .bos, .temiz:
            break
        }

        return result
    }

    // MARK: - Draw Dispatch

    private func drawParticles(ctx: inout GraphicsContext, center: CGPoint, elapsed: Double) {
        switch mood {
        case .atesli:    drawEmbers(ctx: &ctx, center: center, elapsed: elapsed)
        case .enerjik:   drawConfetti(ctx: &ctx, center: center, elapsed: elapsed)
        case .isikli:    drawStars(ctx: &ctx, center: center, elapsed: elapsed)
        case .taze:      drawBubbles(ctx: &ctx, center: center, elapsed: elapsed)
        case .sakin:     drawBubbles(ctx: &ctx, center: center, elapsed: elapsed)
        case .ozgur:     drawDroplets(ctx: &ctx, center: center, elapsed: elapsed)
        case .derin:     drawDroplets(ctx: &ctx, center: center, elapsed: elapsed)
        case .nostaljik: drawDroplets(ctx: &ctx, center: center, elapsed: elapsed)
        case .gizemli:   drawDust(ctx: &ctx, center: center, elapsed: elapsed)
        case .hassas:    drawDust(ctx: &ctx, center: center, elapsed: elapsed)
        case .bos, .temiz: break
        }
    }

    // MARK: - Ateşli: Ember'lar

    private func drawEmbers(ctx: inout GraphicsContext, center: CGPoint, elapsed: Double) {
        let gravity: CGFloat = 600

        for p in particles {
            let t = CGFloat(max(0, elapsed - p.delay))
            guard t > 0 else { continue }
            let progress = Double(t) / p.maxLife
            guard progress < 1.0 else { continue }

            let x = center.x + p.ox + p.vx * t
            let y = center.y + p.oy + p.vy * t + 0.5 * gravity * t * t
            let alpha = pow(1 - progress, 2.0)

            let rect = CGRect(x: x - 1, y: y - p.size / 2, width: 2, height: p.size)
            ctx.fill(Path(rect), with: .color(color.opacity(alpha)))
        }
    }

    // MARK: - Enerjik: Konfeti

    private func drawConfetti(ctx: inout GraphicsContext, center: CGPoint, elapsed: Double) {
        let gravity: CGFloat = 200

        for p in particles {
            let t = CGFloat(max(0, elapsed - p.delay))
            guard t > 0 else { continue }
            let progress = Double(t) / p.maxLife
            guard progress < 1.0 else { continue }

            let x = center.x + p.ox + p.vx * t
            let y = center.y + p.oy + p.vy * t + 0.5 * gravity * t * t
            let alpha = pow(1 - progress, 1.5)

            let rot = (p.rotation0 + p.rotSpeed * Double(t)) * .pi / 180
            let hw = p.size / 2
            let hh = p.size * 0.45

            let corners: [(CGFloat, CGFloat)] = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
            let rotated = corners.map { (cx, cy) -> CGPoint in
                CGPoint(
                    x: x + CGFloat(Double(cx) * cos(rot) - Double(cy) * sin(rot)),
                    y: y + CGFloat(Double(cx) * sin(rot) + Double(cy) * cos(rot))
                )
            }

            var path = Path()
            path.move(to: rotated[0])
            rotated.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()

            ctx.fill(path, with: .color(color.opacity(alpha)))
        }
    }

    // MARK: - Işıklı: 4-Köşeli Yıldızlar

    private func drawStars(ctx: inout GraphicsContext, center: CGPoint, elapsed: Double) {
        for p in particles {
            let t = CGFloat(max(0, elapsed - p.delay))
            guard t > 0 else { continue }
            let progress = Double(t) / p.maxLife
            guard progress < 1.0 else { continue }

            let x = center.x + p.ox + p.vx * t
            let y = center.y + p.oy + p.vy * t
            let alpha = sin(progress * .pi)

            let rot = (p.rotation0 + p.rotSpeed * Double(t)) * .pi / 180
            let outer = p.size
            let inner = p.size * 0.38

            var path = Path()
            for k in 0..<8 {
                let a = Double(k) * .pi / 4 + rot
                let r = k.isMultiple(of: 2) ? outer : inner
                let pt = CGPoint(x: x + CGFloat(cos(a)) * r, y: y + CGFloat(sin(a)) * r)
                if k == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()

            ctx.fill(path, with: .color(color.opacity(alpha)))
        }
    }

    // MARK: - Sakin: Kabarcıklar (stroke daire)

    private func drawBubbles(ctx: inout GraphicsContext, center: CGPoint, elapsed: Double) {
        for p in particles {
            let t = CGFloat(max(0, elapsed - p.delay))
            guard t > 0 else { continue }
            let progress = Double(t) / p.maxLife
            guard progress < 1.0 else { continue }

            let x = center.x + p.ox + CGFloat(sin(Double(t) * 2.8 + Double(p.ox))) * 8
            let y = center.y + p.oy + p.vy * t
            let alpha = sin(progress * .pi) * 0.75

            let r = p.size / 2
            let rect = CGRect(x: x - r, y: y - r, width: p.size, height: p.size)
            ctx.stroke(
                Path(ellipseIn: rect),
                with: .color(color.opacity(alpha)),
                lineWidth: 1.0
            )
        }
    }

    // MARK: - Derin: Damlalar

    private func drawDroplets(ctx: inout GraphicsContext, center: CGPoint, elapsed: Double) {
        let gravity: CGFloat = 150

        for p in particles {
            let t = CGFloat(max(0, elapsed - p.delay))
            guard t > 0 else { continue }
            let progress = Double(t) / p.maxLife
            guard progress < 1.0 else { continue }

            let x = center.x + p.ox + p.vx * t
            let y = center.y + p.oy + p.vy * t + 0.5 * gravity * t * t
            let alpha = pow(1 - progress, 1.8)

            let r = p.size / 2
            let rect = CGRect(x: x - r, y: y - r, width: p.size, height: p.size)
            ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
        }
    }

    // MARK: - Gizemli: Toz

    private func drawDust(ctx: inout GraphicsContext, center: CGPoint, elapsed: Double) {
        for p in particles {
            let t = CGFloat(max(0, elapsed - p.delay))
            guard t > 0 else { continue }
            let progress = Double(t) / p.maxLife
            guard progress < 1.0 else { continue }

            let x = center.x + p.ox + p.vx * t + CGFloat(sin(Double(t) * 1.4 + Double(p.ox))) * 12
            let y = center.y + p.oy + p.vy * t
            let alpha = sin(progress * .pi) * 0.55

            let r = p.size / 2
            let rect = CGRect(x: x - r, y: y - r, width: p.size, height: p.size)
            ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
        }
    }
}
