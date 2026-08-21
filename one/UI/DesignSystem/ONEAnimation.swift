//
//  ONEAnimation.swift
//  one
//
//  Design System - Animation Tokens
//  Provides standardized durations and spring configurations
//

import SwiftUI

/// Animation tokens for the ONE app
/// Provides standardized durations and spring configurations
enum ONEAnimation {
    
    // MARK: - Duration Tokens
    
    /// Micro duration - 0.15s (very quick interactions)
    /// Intended effect: Instant feedback for micro-interactions, feels immediate
    /// Use for: Button presses, toggle switches, small state changes
    static let durationMicro: Double = 0.15
    
    /// Short duration - 0.25s (quick animations)
    /// Intended effect: Quick but noticeable transitions, snappy feel
    /// Use for: Menu transitions, small element animations, quick reveals
    static let durationShort: Double = 0.25
    
    /// Medium duration - 0.35s (standard animations)
    /// Intended effect: Standard comfortable animation speed, balanced feel
    /// Use for: Card movements, panel slides, standard transitions
    static let durationMedium: Double = 0.35
    
    /// Long duration - 0.55s (slow, deliberate animations)
    /// Intended effect: Deliberate, noticeable transitions with weight
    /// Use for: Screen transitions, important state changes, dramatic reveals
    static let durationLong: Double = 0.55
    
    /// Mood background duration - 1.4s (mood gradient transitions)
    /// Intended effect: Smooth, emotional mood color transitions that feel natural
    /// Use for: Mood gradient background changes, emotional state transitions
    static let durationMoodBg: Double = 1.4
    
    /// Pulse duration - 2.0s (pulsing animations)
    /// Intended effect: Gentle rhythmic pulsing that draws attention
    /// Use for: Loading indicators, attention-drawing elements, ambient animations
    static let durationPulse: Double = 2.0
    
    /// Breathe duration - 3.5s (breathing animations)
    /// Intended effect: Slow, calming breathing rhythm for ambient effects
    /// Use for: Background ambient animations, meditative effects, subtle life
    static let durationBreathe: Double = 3.5
    
    // MARK: - Animation Type Configurations
    
    // Aşağıdaki altı token da **kritik sönümlü** (damping 1.0).
    //
    // Neden hepsi: bunların çağrı yerlerinin hiçbiri jest kaynaklı değil —
    // ekran geçişi, bölüm açılışı, kademeli liste girişi, `.animation(_:value:)`
    // ile sürülen bool'lar. Overshoot fiziksel bir borç ödemesidir: parmak
    // momentum taşıdıysa hedefi aşmak doğru okunur, ama kendiliğinden beliren
    // bir panelin zıplaması "yay" değil "arıza" gibi görünür. Bounce artık
    // yalnız `dragSnapBack`/`dragDismiss`'te — orada jest gerçekten hız taşıyor.
    //
    // Response'lar da kısaldı: kritik sönümlü bir yay aynı response'ta
    // alt-sönümlüden geç oturur, eskisiyle aynı bıraksak her şey ağırlaşırdı.

    // MARK: - Easing eğrileri (v3)
    //
    // `cubic-bezier(.2,.9,.25,1)` — v3 handoff'unun eğrisi. `V3Tokens`
    // içinde duruyorlardı; hareketin tek bir yerde yaşaması için buraya
    // taşındılar.
    //
    // Spring'lerle **birlikte** yaşıyorlar, çünkü iki farklı işi var:
    // eğriler süresi bilinen, kesin başlangıç/bitişi olan geçişler için
    // (renk dolgusu, çip seçimi, kayıt onayı); spring'ler ise ekran ve
    // panel hareketi için — orada süre değil, oturma hissi belirleyici.
    // "Tek eğri" iddiası bu yüzden bırakıldı: doğru değildi ve doğru
    // olmasını istemek de yanlış olurdu.

    /// Genel v3 geçişi.
    static let easing      = Animation.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.32)
    /// Basma anı — en kısa.
    static let easingPress = Animation.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.12)
    /// Çip / segment seçimi.
    static let easingChip  = Animation.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.18)
    /// Mood rengi dolgusu.
    static let easingColor = Animation.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.30)
    /// Kaydedildi ekranına geçiş.
    static let easingSaved = Animation.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.36)

    // MARK: - Spring'ler

    /// Micro animation - subtle, quick interactions
    /// Response: 0.22, Damping: 1.0
    static let micro = Animation.spring(response: 0.22, dampingFraction: 1.0)

    /// Card spring - card movements, screen switches, staggered list entrances
    /// Response: 0.36, Damping: 1.0
    static let cardSpring = Animation.spring(response: 0.36, dampingFraction: 1.0)

    /// Panel spring - panel and sheet transitions
    /// Response: 0.38, Damping: 1.0
    static let panelSpring = Animation.spring(response: 0.38, dampingFraction: 1.0)

    /// Screen transition - full screen changes
    /// Response: 0.44, Damping: 1.0
    static let screenTransition = Animation.spring(response: 0.44, dampingFraction: 1.0)

    /// Mood transition - deliberately slow (emotional color shifts)
    /// Response: 0.55, Damping: 1.0
    static let moodTransition = Animation.spring(response: 0.55, dampingFraction: 1.0)

    /// Tab switch - a tap, not a flick: snappy but without overshoot
    /// Response: 0.26, Damping: 1.0
    static let tabSwitch = Animation.spring(response: 0.26, dampingFraction: 1.0)

    // MARK: - Gesture-Driven Springs

    /// Sürükleme eşiği aşılmadığında elemanın yerine dönüşü.
    ///
    /// `interactiveSpring` + `blendDuration`: kullanıcı geri dönen elemanı
    /// yolda tekrar yakalarsa hareket kesilmeden devralınıyor. Düz `spring`
    /// bunu yapamıyordu — yeni jest, hızı sıfırdan başlatıp görünür bir
    /// duraklama üretiyordu.
    /// Uygulamada bilerek bounce bırakılan **tek** yer burası: jest hızla
    /// bitti, eleman o hızı taşıyarak yerine dönüyor. Apple'ın çekmece/sheet
    /// değerleri (damping 0.8, response 0.3).
    /// Response: 0.32, Damping: 0.80, Blend: 0.15
    static let dragSnapBack = Animation.interactiveSpring(
        response: 0.32, dampingFraction: 0.80, blendDuration: 0.15
    )

    /// Sürükleyerek kapatma onaylandığında elemanın ekran dışına uçuşu.
    ///
    /// Kritik sönümlü (0.72 değil 1.0): eleman ekrandan çıkıyor, orada
    /// salınacak bir yer yok. Sabit süreli `easeOut` yerine spring, çünkü
    /// kapanış da kesintiye uğratılabilir olmalı.
    /// Response: 0.34, Damping: 1.0, Blend: 0.1
    static let dragDismiss = Animation.interactiveSpring(
        response: 0.34, dampingFraction: 1.0, blendDuration: 0.1
    )
    
    // MARK: - Stagger Animation
    
    /// Calculate stagger delay for list item animations
    /// Intended effect: Sequential reveal of list items with cascading timing
    /// Use for: List animations, sequential reveals, cascading effects
    /// - Parameters:
    ///   - index: Item index in the list
    ///   - baseDelay: Base delay between items (default: 0.08)
    /// - Returns: Delay in seconds for this item
    static func staggerDelay(index: Int, baseDelay: Double = 0.07) -> Double {
        return Double(index) * baseDelay
    }
    
    // MARK: - Button Press Style
    
    /// Scale for pressed button state
    /// Intended effect: Subtle scale-down that provides tactile feedback
    /// Use for: All button press interactions
    static let buttonPressScale: CGFloat = 0.96
    
    /// Animation for button press
    /// Intended effect: Quick, responsive press with slight bounce
    /// Use for: Button press down animation
    ///
    /// v3: spring'den tek easing eğrisine geçti. `.onePressable` uygulamada
    /// 60'tan fazla yerde kullanılıyor; spring kaldığı sürece o butonların
    /// hepsi v3'ün `cubic-bezier(.2,.9,.25,1)` kuralının dışında kalıyordu —
    /// yeni v3 bileşenleri (`V3TopBar`, `SubScreenNavBar`) dahil.
    static let buttonPressAnimation = easingPress
    
    /// Animation for button release
    /// Intended effect: Smooth return to normal state with controlled bounce
    /// Use for: Button release animation
    static let buttonReleaseAnimation = easingChip
}

// MARK: - Animation View Modifiers

extension View {

    /// Apply button press animation effect
    /// - Parameter isPressed: Whether button is currently pressed
    func buttonPressEffect(isPressed: Bool) -> some View {
        self.scaleEffect(isPressed ? ONEAnimation.buttonPressScale : 1.0)
            .animation(
                isPressed ? ONEAnimation.buttonPressAnimation : ONEAnimation.buttonReleaseAnimation,
                value: isPressed
            )
    }

    /// Apply a standard page entrance animation (opacity + scale + vertical offset)
    /// Reduce Motion: offset/scale atlanır, sadece opacity geçişi yapılır.
    /// - Parameters:
    ///   - isVisible: Whether the element is visible (drive with @State appeared)
    ///   - delay: Delay before this element's entrance (default: 0)
    func pageEntrance(isVisible: Bool, delay: Double = 0) -> some View {
        modifier(PageEntranceModifier(isVisible: isVisible, delay: delay))
    }

    /// Apply a staggered list item entrance animation (opacity + vertical offset)
    /// Reduce Motion: offset atlanır, sadece opacity; stagger delay = 0.
    /// - Parameters:
    ///   - isVisible: Whether the item is visible
    ///   - index: Item index for stagger delay calculation
    ///   - baseDelay: Base delay before first item appears (default: 0)
    func listItemEntrance(isVisible: Bool, index: Int, baseDelay: Double = 0) -> some View {
        modifier(ListItemEntranceModifier(isVisible: isVisible, index: index, baseDelay: baseDelay))
    }

    /// Apply a standard directional slide transition
    /// Reduce Motion: sadece opacity transition kullanılır.
    /// - Parameter edge: The edge from which the element enters (default: .bottom)
    func slideTransition(edge: Edge = .bottom) -> some View {
        modifier(SlideTransitionModifier(edge: edge))
    }
}

// MARK: - Reduce-Motion-Aware Modifier Implementations

private struct PageEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isVisible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.90))
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 20))
            .animation(
                reduceMotion
                    ? .easeOut(duration: ONEAnimation.durationMicro)
                    : ONEAnimation.panelSpring.delay(delay),
                value: isVisible
            )
    }
}

private struct ListItemEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isVisible: Bool
    let index: Int
    let baseDelay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.92))
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 22))
            .animation(
                reduceMotion
                    ? .easeOut(duration: ONEAnimation.durationMicro)
                    : ONEAnimation.cardSpring.delay(baseDelay + ONEAnimation.staggerDelay(index: index)),
                value: isVisible
            )
    }
}

private struct SlideTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let edge: Edge

    func body(content: Content) -> some View {
        if reduceMotion {
            content.transition(.opacity)
        } else {
            // Girdiği yoldan çıkar. Kenardan girip yerinde solmak, elemanın
            // nereye gittiğine dair mekânsal ipucunu siliyordu — bir sonraki
            // açılışta nereden geleceği de tahmin edilemez oluyor.
            content.transition(.move(edge: edge).combined(with: .opacity))
        }
    }
}

// MARK: - Breathing Animation Modifier

struct BreathingAnimation: ViewModifier {
    let delay: Double
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect((!reduceMotion && isAnimating) ? 1.05 : 1.0)
            .opacity(isAnimating ? 0.6 : 0.3)
            .animation(
                reduceMotion
                    ? .easeOut(duration: ONEAnimation.durationMicro)
                    : Animation.easeInOut(duration: ONEAnimation.durationBreathe)
                        .repeatForever(autoreverses: true)
                        .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    /// Apply breathing animation effect
    /// - Parameter delay: Delay before animation starts (default: 0)
    func breathingAnimation(delay: Double = 0) -> some View {
        self.modifier(BreathingAnimation(delay: delay))
    }
}
