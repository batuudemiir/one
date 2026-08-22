//
//  SplashScreen.swift
//  one
//
//  v3 splash — kor zemin + bone kelime işareti. Tek hareket, sub-second.
//
//  Timeline (v3 tek easing eğrisi: cubic-bezier(.2,.9,.25,1)):
//   0.00s → kor zemin **zaten oradadır** (animasyon yok, ilk kare hazır)
//   0.00s → "ONE" belirir (0.30s: opacity 0→1, scale 0.94→1)
//   0.14s → alt satır belirir (0.26s: opacity 0→0.72, translateY 5→0)
//   ≥0.42s → hazırsa kabuğa devredilir; kabuk kendi crossfade'ini yapar
//
//  Neden bu tasarım:
//   - Eski sürüm ekranın 1.5 katı bir `Circle`'ı `.drawingGroup()` ile
//     rasterize edip 0.06→1.0 ölçekliyordu. Bu, cold start'ta CloudKit ve
//     CoreData işiyle **aynı anda** büyük bir offscreen render tetikliyor ve
//     ilk saniyede takılma yaratıyordu. Zemin artık düz renk — bedava.
//   - Eski sürümde kor kare işaret, kor yıkamanın altında kayboluyordu
//     (kor üstüne kor). Artık işaret bone metin, zemin kor: her an okunur.
//   - Eski sürümde splash kendi outro'sunu (0.28s fade) yapıyor, ardından
//     `ContentView` bir kez daha kabuğu fade+scale ediyordu — iki geçiş
//     üst üste binince hareket "sünüyordu". Artık geçişin tek sahibi
//     `ContentView`; splash yalnızca `isActive`'i çeviriyor.
//   - Sabit 1.04s duvar saati kaldırıldı. Alt sınır 0.42s; launch işi daha
//     erken biterse splash daha erken kapanır.
//
//  Reduce Motion: hareket yok, 0.18s fade ve 0.20s alt sınır.
//

import SwiftUI
import UIKit

struct SplashScreen: View {
    @Binding var isActive: Bool

    /// Set by the host when critical launch work (CloudKit user resolution etc.)
    /// finishes. Splash uses this to dismiss as early as safely possible.
    var appReady: Bool = true

    /// Namespace shared with the host so the mark can hand off to the
    /// main-shell anchor via `matchedGeometryEffect`.
    var handoffNamespace: Namespace.ID? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Kelime işaretinin ekranda kalacağı en kısa süre. Markayı okumaya yeter,
    /// beklemeye dönüşmez.
    ///
    /// Koreografi ile hizalı: alt satır 0.10s'de başlayıp 0.22s sürüyor,
    /// yani 0.32s'de duruyor. Alt sınır onun hemen ardında — animasyon
    /// yarıda kesilmiyor ama bir kare bile fazla beklenmiyor.
    private var minimumShowTime: TimeInterval { reduceMotion ? 0.16 : 0.34 }

    // Choreography state — üçü de tek seferde hedefe gider, retarget yok.
    @State private var markOpacity: Double = 0
    @State private var markScale: CGFloat = 0.94
    @State private var captionOpacity: Double = 0
    @State private var captionOffset: CGFloat = 5


    // Timing bookkeeping
    @State private var minimumTimeElapsed = false
    @State private var didStart = false
    @State private var didFireHaptic = false
    @State private var isDismissing = false

    var body: some View {
        ZStack {
            // Düz kor zemin — maske, mask animasyonu, drawingGroup yok.
            // İlk kare hiçbir hazırlık istemiyor.
            ONEBrand.kor
                .ignoresSafeArea()

            VStack(spacing: V3Tokens.spacingLG) {
                splashMark
                    .modifier(HandoffSource(namespace: handoffNamespace))
                    .opacity(markOpacity)
                    .scaleEffect(markScale)

                // Alt satır okunacak metin — ölçeklenmeye devam ediyor, ama
                // tek satırlık tracking'li bir şerit olduğu için taşmak
                // yerine sıkışsın.
                Text(NSLocalizedString("splash.tagline", comment: ""))
                    .font(V3Typography.mono(11, weight: .regular))
                    .tracking(1.6)
                    .foregroundColor(ONEBrand.bone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, V3Tokens.channel)
                    .opacity(captionOpacity)
                    .offset(y: captionOffset)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("ONE"))
        .onAppear {
            guard !didStart else { return }
            didStart = true
            ONELaunchSignpost.begin("splash")
            ONEHaptics.warmUp()
            start()
        }
        .onChange(of: minimumTimeElapsed) { _, _ in maybeDismiss() }
        .onChange(of: appReady) { _, _ in maybeDismiss() }
    }

    // MARK: - Splash mark

    /// Kare rozet değil — kabuğun üst barındaki kor "ONE" ile aynı tipografik
    /// nesne. `matchedGeometryEffect` böylece bir kutuyu metne değil, metni
    /// metne taşıyor: devir tek ve doğal bir hareket oluyor.
    private var splashMark: some View {
        Text("ONE")
            // `displayFixed` — marka işareti Dynamic Type ile büyümüyor.
            // Hem marka oranları sabit kalsın diye, hem de bu metin
            // `matchedGeometryEffect`'in kaynağı: boyutu kullanıcı ayarına
            // göre oynarsa kabuğa devir de oynardı.
            .font(V3Typography.displayFixed(46))
            .tracking(-1.6)
            .foregroundColor(ONEBrand.bone)
            .lineLimit(1)
            .fixedSize()
    }

    // MARK: - Choreography

    /// v3 cubic-bezier(.2, .9, .25, 1) — the single easing curve.
    private static func v3(_ duration: TimeInterval, delay: TimeInterval = 0) -> Animation {
        .timingCurve(0.2, 0.9, 0.25, 1.0, duration: duration).delay(delay)
    }

    private func start() {
        if reduceMotion {
            markScale = 1
            captionOffset = 0
            withAnimation(.easeOut(duration: 0.14)) {
                markOpacity = 1
                captionOpacity = 0.72
            }
        } else {
            // Tek withAnimation, tek hedef — ortada yeniden hedeflenen
            // (retarget) bir özellik yok, dolayısıyla snap de yok.
            withAnimation(Self.v3(0.26)) {
                markOpacity = 1
                markScale = 1
            }
            withAnimation(Self.v3(0.22, delay: 0.10)) {
                captionOpacity = 0.72
                captionOffset = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + minimumShowTime) {
            minimumTimeElapsed = true
        }
    }

    // MARK: - Dismiss

    private func maybeDismiss() {
        guard !isDismissing, minimumTimeElapsed, appReady else { return }
        isDismissing = true

        ONELaunchSignpost.begin("splash.handoff")

        if !didFireHaptic && !reduceMotion {
            didFireHaptic = true
            ONEHaptics.appReady()
        }

        // Kendi outro'muz yok. `ContentView` bu bayrağı izleyip splash'i
        // kaldırırken kabuğu aynı anda açıyor — tek crossfade, tek zamanlama.
        ONELaunchSignpost.end("splash")
        isActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            ONELaunchSignpost.end("splash.handoff")
        }
    }
}

// MARK: - Handoff source modifier

private struct HandoffSource: ViewModifier {
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let ns = namespace {
            content.matchedGeometryEffect(
                id: SplashHandoff.wordmarkID,
                in: ns,
                properties: .frame,
                anchor: .center,
                isSource: true
            )
        } else {
            content
        }
    }
}

/// Namespace identifiers shared between SplashScreen and the main shell.
enum SplashHandoff {
    static let wordmarkID = "one.splash.wordmark"
}

#Preview("Cold") {
    SplashScreen(isActive: .constant(false), appReady: true)
}

#Preview("Awaiting readiness") {
    SplashScreen(isActive: .constant(false), appReady: false)
}
