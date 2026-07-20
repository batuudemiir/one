//
//  SaveRitualMoment.swift
//  one
//
//  Kayıt anı — tek imza. Beş dönüşümlü kutlama yerine her seferinde
//  aynı, tanınabilir olay.
//

import SwiftUI

// MARK: - Ripple modifier

/// Kayıt anında ekranın kendisini büken dalga.
///
/// Neden shader: `.distortionEffect` altındaki view'ın **piksellerini**
/// yeniden örnekliyor. Üstüne çizilen bir halka "bir animasyon oynadı"
/// der; bükülen ekran "bir şey oldu" der. Kayıt günün tek eylemi olduğu
/// için ikincisini hak ediyor.
///
/// Reduce Motion'da tamamen atlanır — bu efekt vestibüler rahatsızlık
/// yaratabilecek türden ve alternatifi sade bir soluşma.
struct SaveRippleModifier: ViewModifier {
    /// Dalganın başladığı an. nil ise efekt yok.
    let start: Date?
    /// Merkez — kayıt butonunun konumu. Birim kare (0…1) içinde.
    var originUnit: CGPoint = CGPoint(x: 0.5, y: 0.62)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Dalganın ekranı terk etmesi ~1.4 s sürüyor; sonrasında shader'ı
    /// tamamen devreden çıkarıyoruz ki boşuna her kareyi yeniden çizmesin.
    private let duration: TimeInterval = 1.4

    func body(content: Content) -> some View {
        if reduceMotion || start == nil {
            content
        } else {
            TimelineView(.animation(paused: false)) { timeline in
                GeometryReader { geo in
                    let elapsed = start.map { timeline.date.timeIntervalSince($0) } ?? 0
                    let origin = CGPoint(
                        x: geo.size.width * originUnit.x,
                        y: geo.size.height * originUnit.y
                    )

                    if elapsed >= 0 && elapsed <= duration {
                        content
                            .distortionEffect(
                                ShaderLibrary.oneSaveRipple(
                                    .float2(origin),
                                    .float(Float(elapsed)),
                                    .float(14),     // amplitude
                                    .float(11),     // frequency
                                    .float(5.2),    // decay
                                    .float(760)     // speed
                                ),
                                maxSampleOffset: CGSize(width: 24, height: 24)
                            )
                            .layerEffect(
                                ShaderLibrary.oneSaveChroma(
                                    .float2(origin),
                                    .float(Float(elapsed)),
                                    .float(760),    // speed — ripple ile aynı
                                    .float(34),     // band genişliği
                                    .float(0.9)     // kayma şiddeti (px)
                                ),
                                maxSampleOffset: CGSize(width: 2, height: 2)
                            )
                    } else {
                        content
                    }
                }
            }
        }
    }
}

extension View {
    /// Kayıt dalgası. `start` set edildiği anda tetiklenir.
    func saveRipple(start: Date?, origin: CGPoint = CGPoint(x: 0.5, y: 0.62)) -> some View {
        modifier(SaveRippleModifier(start: start, originUnit: origin))
    }
}

// MARK: - Bloom + seal

/// Dalganın üstüne binen katman: mood renginin açılması ve mühür.
///
/// iOS 18'de `MeshGradient` kullanılıyor — renk düz bir daire değil,
/// nefes alan bir alan. 17'de radyal gradyana düşüyor; ikisi de aynı
/// koreografiyi izlediği için sürüm farkı bir eksiklik gibi durmuyor.
struct SaveRitualMoment: View {
    let mood: ONEMood
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .idle

    /// Mührün üç aşaması — `KeyframeAnimator` yerine açık bir faz makinesi:
    /// her aşamanın kendi haptiği var ve sıra dışarıdan okunabilir olmalı.
    private enum Phase { case idle, bloom, sealed, fading }

    var body: some View {
        ZStack {
            bloom
            seal
        }
        .allowsHitTesting(false)
        .onAppear(perform: run)
    }

    // MARK: Bloom

    @ViewBuilder
    private var bloom: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: meshPoints,
                colors: meshColors
            )
            .ignoresSafeArea()
            .opacity(phase == .idle ? 0 : (phase == .fading ? 0 : 0.55))
            .animation(.easeOut(duration: 0.55), value: phase)
            .blur(radius: 18)
        } else {
            RadialGradient(
                colors: [mood.color.opacity(0.42), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 360
            )
            .ignoresSafeArea()
            .opacity(phase == .idle ? 0 : (phase == .fading ? 0 : 1))
            .animation(.easeOut(duration: 0.55), value: phase)
        }
    }

    /// Mesh kontrol noktaları. Bloom aşamasında dışa doğru esniyorlar —
    /// rengin "yayıldığı" hissi buradan geliyor, opacity'den değil.
    private var meshPoints: [SIMD2<Float>] {
        let spread: Float = (phase == .idle) ? 0.0 : 0.18
        return [
            SIMD2(0, 0),                    SIMD2(0.5, 0 - spread * 0.5), SIMD2(1, 0),
            SIMD2(0 - spread * 0.5, 0.5),   SIMD2(0.5, 0.5),              SIMD2(1 + spread * 0.5, 0.5),
            SIMD2(0, 1),                    SIMD2(0.5, 1 + spread * 0.5), SIMD2(1, 1)
        ]
    }

    private var meshColors: [Color] {
        let c = mood.color
        let p = mood.pastelColor
        return [
            .clear, p.opacity(0.5), .clear,
            p.opacity(0.5), c, p.opacity(0.5),
            .clear, p.opacity(0.5), .clear
        ]
    }

    // MARK: Seal

    private var seal: some View {
        Circle()
            .fill(mood.color)
            .frame(width: 104, height: 104)
            .overlay(
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundColor(.white)
            )
            .shadow(color: mood.color.opacity(0.45), radius: 24, y: 10)
            .scaleEffect(sealScale)
            .opacity(phase == .idle ? 0 : (phase == .fading ? 0 : 1))
            .animation(.spring(response: 0.42, dampingFraction: 0.58), value: phase)
    }

    private var sealScale: CGFloat {
        switch phase {
        case .idle:   return 0.3
        case .bloom:  return 0.86
        case .sealed: return 1.0
        case .fading: return 1.08
        }
    }

    // MARK: Choreography

    private func run() {
        guard !reduceMotion else {
            // Sade yol: tek bir soluşma, hareket yok.
            phase = .sealed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                phase = .fading
                onFinished()
            }
            return
        }

        ONEHaptics.saveRitual(mood: mood)
        phase = .bloom

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            ONEHaptics.saveRitualPeak()
            phase = .sealed
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.easeOut(duration: 0.4)) { phase = .fading }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            onFinished()
        }
    }
}
