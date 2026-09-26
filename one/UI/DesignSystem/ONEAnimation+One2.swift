//
//  ONEAnimation+One2.swift
//  one
//
//  ONE 2.0 hareket token'ları. Değerler `docs/one2/design-system/README.md`
//  › "Hareket ve geri bildirim" ile bileşen kartlarından (Button, Seal,
//  ScoreScale) geliyor; kural seti `docs/one2/06_premium_his.md`.
//
//  v3 token'ları (`ONEAnimation.easing*`, spring'ler) olduğu gibi kalıyor:
//  App Store'daki v3 kabuğu onları kullanıyor. ONE 2.0 bileşenleri yalnız
//  bu isim alanını okur. İkisinin eğrisi farklı; birleştirme kararı açık
//  (06_premium_his.md › "Açık kararlar").
//

import SwiftUI

extension ONEAnimation {

    enum One2 {

        // MARK: - Eğri
        //
        // Tek eğri: `cubic-bezier(0.2, 0.8, 0.2, 1)`. Hızlı çıkıp yavaş
        // oturuyor; doğrusal hareket ONE 2.0'da yok. Süreler aşağıda,
        // eğri hep aynı — hareketin "bir karar" gibi okunmasının yolu bu.

        static func curve(_ duration: Double) -> Animation {
            .timingCurve(0.2, 0.8, 0.2, 1.0, duration: duration)
        }

        // MARK: - Süreler

        /// Basış: 120ms.
        static let durationPress: Double = 0.12
        /// Çip ve seçim: 180ms.
        static let durationChip: Double = 0.18
        /// Ekran ve adım geçişi: 280ms.
        static let durationScreen: Double = 0.28
        /// Mühür: 320ms, tek sefer.
        static let durationSeal: Double = 0.32
        /// Skor seçiminden sonraki adıma geçiş beklemesi: 300ms.
        /// Seçimin görülmesine yer bırakır; akışın ritmi buradan gelir.
        static let stepAdvanceDelay: Double = 0.30

        // MARK: - Animasyonlar

        static let press  = curve(durationPress)
        static let chip   = curve(durationChip)
        static let screen = curve(durationScreen)
        static let seal   = curve(durationSeal)

        /// Reduce Motion'da her şey yalnız opaklıkla ve bu sürede değişir.
        static let reducedFade = Animation.easeOut(duration: ONEAnimation.durationMicro)

        // MARK: - Ölçekler

        /// Basışta küçülme (Button kartı: `scale(0.97)`).
        static let pressScale: CGFloat = 0.97
        /// Mühür diskinin başlangıç ölçeği (Seal kartı: 0.9 → 1.0).
        static let sealStartScale: CGFloat = 0.9
    }
}

// MARK: - Mühür girişi

extension View {

    /// Mührün tek seferlik girişi: 0.9 → 1.0 + opaklık, 320ms.
    /// Reduce Motion: ölçek atlanır, yalnız opaklık.
    /// Haptiği çağıran taraf verir (`ONEHaptics.one2Seal()`), animasyonla
    /// aynı anda — hareket ve dokunuş tek bir olay gibi hissedilmeli.
    func one2SealEntrance(isVisible: Bool) -> some View {
        modifier(One2SealEntranceModifier(isVisible: isVisible))
    }
}

private struct One2SealEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion || isVisible ? 1 : ONEAnimation.One2.sealStartScale)
            .animation(
                reduceMotion ? ONEAnimation.One2.reducedFade : ONEAnimation.One2.seal,
                value: isVisible
            )
    }
}
