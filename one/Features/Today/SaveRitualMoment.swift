//
//  SaveRitualMoment.swift
//  one
//
//  Kayıt anı — tek imza. Beş dönüşümlü kutlama yerine her seferinde
//  aynı, tanınabilir olay.
//

import SwiftUI

// MARK: - Ripple field

/// Kayıt anının dalgası — Metal ile bükülen, kendi kendine yeten katman.
///
/// **Bu shader'lar bilerek uygulamanın içeriğine UYGULANMIYOR.**
/// `.distortionEffect` / `.layerEffect` altındaki ağacı ekran dışında
/// rasterize ediyor. O ağaçta arka planını örnekleyen bir yüzey varsa —
/// iOS 26+ `glassEffect` (Liquid Glass) tam olarak öyle — örnekleyecek
/// arka plan kalmıyor ve kare boş çiziliyor. Kaydettikten sonra ekranın
/// beyaz kalmasının sebebi buydu: `TodayCompletedView` üç yerde
/// `.liquidGlass(...)` kullanıyor ve cihaz iOS 26+ olduğu için gerçek
/// cam çiziliyordu.
///
/// Buradaki ağaçta yalnızca şekil var: güvenle rasterize olur ve efekt
/// kimsenin arka planına bağlı değil.
///
/// Reduce Motion'da hiç çizilmez — bu efekt vestibüler rahatsızlık
/// yaratabilecek türden.
struct SaveRippleField: View {
    let mood: V3Mood
    /// Dalganın başladığı an.
    let start: Date

    /// Cephe hızı (pt/sn). Shader ile çizim aynı değeri paylaşıyor,
    /// yoksa prizmatik kenar halkanın üstüne oturmuyor.
    private let speed: Double = 760
    /// Dalganın toplam ömrü. Bundan sonra her iki shader da birim
    /// dönüşüme iner — boşuna kare çizmemek için katman kapanır.
    private let lifetime: Double = 1.6

    var body: some View {
        GeometryReader { geo in
            let origin = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
            let reach  = hypot(geo.size.width, geo.size.height)

            TimelineView(.animation) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(start))

                rings(reach: reach, elapsed: elapsed)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .distortionEffect(
                        ShaderLibrary.oneSaveRipple(
                            .float2(Float(origin.x), Float(origin.y)),
                            .float(Float(elapsed)),
                            .float(18),     // amplitude
                            .float(11),     // frequency
                            .float(4.6),    // decay
                            .float(Float(speed))
                        ),
                        maxSampleOffset: CGSize(width: 30, height: 30)
                    )
                    .layerEffect(
                        ShaderLibrary.oneSaveChroma(
                            .float2(Float(origin.x), Float(origin.y)),
                            .float(Float(elapsed)),
                            .float(Float(speed)),
                            .float(40),     // band genişliği
                            .float(1.2)     // kayma şiddeti (px)
                        ),
                        maxSampleOffset: CGSize(width: 3, height: 3)
                    )
                    .opacity(elapsed > lifetime ? 0 : 1)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Genişleyen üç cephe. Halkalar mükemmel daire olarak başlıyor,
    /// shader onları bükünce organik bir dalgaya dönüşüyorlar — asıl
    /// etkiyi yapan bu, halkanın kendisi değil.
    private func rings(reach: CGFloat, elapsed: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let delay    = Double(index) * 0.16
                let progress = min(max(0, elapsed - delay) / 1.15, 1)
                let fade     = 1 - progress

                Circle()
                    .stroke(
                        mood.color.opacity(0.55 * fade),
                        lineWidth: 3.2 - Double(index) * 0.7
                    )
                    .frame(width: reach * progress, height: reach * progress)
            }
        }
    }
}

// MARK: - Bloom + seal

/// Dalganın üstüne binen katman: mood renginin açılması ve mühür.
///
/// iOS 18'de `MeshGradient` kullanılıyor — renk düz bir daire değil,
/// nefes alan bir alan. 17'de radyal gradyana düşüyor; ikisi de aynı
/// koreografiyi izlediği için sürüm farkı bir eksiklik gibi durmuyor.
struct SaveRitualMoment: View {
    let mood: V3Mood
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .idle
    /// Dalganın sıfır anı. View doğduğunda sabitleniyor — dışarıdan
    /// taşınan bir tarih, sahibi silinse bile shader'ı açık bırakabilir.
    @State private var start = Date()

    /// Mührün üç aşaması — `KeyframeAnimator` yerine açık bir faz makinesi:
    /// her aşamanın kendi haptiği var ve sıra dışarıdan okunabilir olmalı.
    private enum Phase { case idle, bloom, sealed, fading }

    var body: some View {
        ZStack {
            // Dalga en altta: bloom ve mühür onun üstünde okunur kalmalı.
            // Shader artık burada — koreografiyi zaten bu view yönetiyor,
            // ömrü de sahibiyle birlikte bitiyor.
            if !reduceMotion {
                SaveRippleField(mood: mood, start: start)
            }
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
        // MeshGradient noktaları [0,1] ARALIĞINDA olmak zorunda; dışına
        // taşan nokta gradyanı bozuyor. Esneme bu yüzden dışa değil,
        // ORTA satır/sütunu içe çekerek yapılıyor — aynı "yayılma"
        // hissi, geçerli aralıkta.
        let s: Float = (phase == .idle) ? 0.5 : 0.5 - 0.12
        let e: Float = (phase == .idle) ? 0.5 : 0.5 + 0.12
        return [
            SIMD2(0, 0),    SIMD2(0.5, 0),  SIMD2(1, 0),
            SIMD2(0, s),    SIMD2(0.5, 0.5), SIMD2(1, e),
            SIMD2(0, 1),    SIMD2(0.5, 1),  SIMD2(1, 1)
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

    /// Kaydın dört vuruşluk duygusal yayı. Ritüelin **tek** sahibi burası;
    /// `V3EntryContainer` aynı yayı ayrıca çalıyordu ve her kayıt iki kez
    /// titriyordu (üstelik iki farklı mood eşlemesiyle).
    ///
    ///  t=0      → moodun kendi taktil dili (CoreHaptics, mood'a özgü)
    ///  t=0.28s  → hafif peak "tık" — görsel `sealed` fazıyla aynı an
    ///  t=0.45s  → net "yerine oturdu" darbesi (rigid impact)
    ///  t=0.65s  → kutlama, notification success
    ///
    /// Sıra iki iş yapıyor: bekleme değil bir *olay* hissi kurar, ve mood ne
    /// olursa olsun sonda "kaydedildi" sinyalini hep aynı tonda kapatır.
    private func playHapticArc() {
        ONEHaptics.saveRitual(mood: mood)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            ONEHaptics.saveRitualPeak()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            ONEHaptics.saveRitualSeal()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            ONEHaptics.songSaved()
        }
    }

    private func run() {
        // Haptic yay her koşulda çalıyor — Reduce Motion **hareketi** kapatır,
        // dokunsal geri bildirimi değil. Eskiden erken `return` yüzünden
        // Reduce Motion açık kullanıcılar kayıtta hiçbir şey hissetmiyordu.
        playHapticArc()

        guard !reduceMotion else {
            // Sade yol: tek bir soluşma, hareket yok.
            phase = .sealed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                phase = .fading
                onFinished()
            }
            return
        }

        // Faz değişimi bir tick ERTELENİYOR: `onAppear` içinde senkron
        // değiştirilirse SwiftUI ilk kareyi zaten hedef değerle çiziyor
        // ve implicit animasyon interpolasyon yapmıyor — mühür "beliriyor"
        // ama içeri yaylanmıyordu. Ayrıca artık explicit withAnimation.
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
                phase = .bloom
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) {
                phase = .sealed
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.easeOut(duration: 0.4)) { phase = .fading }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            onFinished()
        }
    }
}
