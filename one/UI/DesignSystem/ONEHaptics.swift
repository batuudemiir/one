//
//  ONEHaptics.swift
//  one
//
//  Design System - Haptic Feedback Tokens
//  Provides standardized haptic feedback for consistent, premium tactile responses.
//  saveRitual: CoreHaptics (CHHapticEngine) kullanır — tam zamanlama kontrolü,
//  iOS UIKit cooldown bypass, mood'a özgü çok adımlı titreşim dizileri.
//

import UIKit
import CoreHaptics

/// Haptic feedback tokens for the ONE app.
/// All haptic calls in the app should go through this enum to ensure
/// a consistent, intentional tactile language throughout the experience.
enum ONEHaptics {

    // MARK: - CoreHaptics Engine (saveRitual için)

    /// Paylaşılan CHHapticEngine instance'ı.
    /// Lazy başlatılır, hata durumunda nil olur (eski cihaz uyumluluğu).
    private static var engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true
            try e.start()
            return e
        } catch {
            return nil
        }
    }()

    /// Engine'i gerektiğinde yeniden başlatır (arka plan/ön plan geçişlerinde durabilir).
    private static func ensureEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if engine == nil {
            engine = try? CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
        }
        try? engine?.start()
    }

    /// CoreHaptics ile özel bir titreşim dizisi çalar.
    /// - Parameter events: (relativeTime, intensity, sharpness) tuple dizisi
    private static func playPattern(_ events: [(time: Double, intensity: Float, sharpness: Float)]) {
        ensureEngine()
        guard let engine else {
            // CoreHaptics desteklenmiyor — UIKit fallback
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred()
            return
        }
        do {
            let hapticEvents: [CHHapticEvent] = events.map { ev in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: ev.intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: ev.sharpness)
                    ],
                    relativeTime: ev.time
                )
            }
            let pattern = try CHHapticPattern(events: hapticEvents, parameters: [])
            let player  = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Sessiz hata — fallback
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
        }
    }

    // MARK: - Song & Entry

    /// Fired once when a daily entry is successfully saved.
    /// Strong, celebratory — the "ONE moment" confirmation.
    static func songSaved() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    /// Fired at the start of the Save Ritual — mood'a özgü taktil dil.
    /// CoreHaptics ile tam zamanlama kontrolü — iOS cooldown bypass.
    ///
    /// intensity: 0.0–1.0 (güç)
    /// sharpness: 0.0 yumuşak/küt, 1.0 keskin/mekanik
    static func saveRitual(mood: ONEMood?) {
        switch mood {

        case .atesli:
            // Patlama + mini ikinci darbe — sert, keskin
            playPattern([
                (time: 0.00, intensity: 1.00, sharpness: 0.90),  // ana patlama
                (time: 0.12, intensity: 0.65, sharpness: 0.70),  // ikinci darbe
            ])

        case .enerjik:
            // Bounce çift — ana + echo, orta keskinlik
            playPattern([
                (time: 0.00, intensity: 0.80, sharpness: 0.60),
                (time: 0.14, intensity: 0.45, sharpness: 0.40),
            ])

        case .isikli:
            // Tek, yumuşak ışık — düşük sharpness
            playPattern([
                (time: 0.00, intensity: 0.65, sharpness: 0.20),
            ])

        case .sakin:
            // Nefes gibi — çok hafif, küt
            playPattern([
                (time: 0.00, intensity: 0.30, sharpness: 0.10),
            ])

        case .derin:
            // Su damlası — iki dalga, aralarında duraklama
            playPattern([
                (time: 0.00, intensity: 0.60, sharpness: 0.40),
                (time: 0.30, intensity: 0.30, sharpness: 0.20),
            ])

        case .gizemli:
            // Ağır tek darbe — orta güç, yüksek sharpness (rigid hissi)
            playPattern([
                (time: 0.00, intensity: 0.55, sharpness: 0.85),
            ])

        case .bos:
            // Minimal — barely there
            playPattern([
                (time: 0.00, intensity: 0.22, sharpness: 0.15),
            ])

        case .temiz:
            // Sade, hafif tık
            playPattern([
                (time: 0.00, intensity: 0.40, sharpness: 0.50),
            ])

        default:
            playPattern([
                (time: 0.00, intensity: 0.60, sharpness: 0.50),
            ])
        }
    }

    // MARK: - Selection

    /// Fired when a mood color is selected.
    /// Medium impact — meaningful but not jarring.
    static func moodSelected() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred(intensity: 0.65)
    }

    /// Fired when a feeling/emotion is selected.
    /// Softer than mood — a gentle acknowledgment.
    static func feelingSelected() {
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        gen.impactOccurred(intensity: 0.6)
    }

    // MARK: - Navigation

    /// Fired on bottom tab switch.
    /// Light selection feedback — non-intrusive.
    static func tabSwitch() {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }

    // MARK: - Social / Circle

    /// Fired when a friend is successfully connected.
    /// Strong, meaningful — marks a social connection.
    static func friendConnected() {
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: 0.8)
    }

    // MARK: - System Events

    /// Fired on midnight day reset (if app is open).
    /// Very soft — ambient, barely noticeable.
    static func dayReset() {
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        gen.impactOccurred(intensity: 0.3)
    }

    /// Fired on error or invalid action.
    static func error() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.error)
    }

    // MARK: - Camera

    /// Fired at the moment a photo is captured.
    /// Heavy — mimics a physical shutter press.
    static func photoCapture() {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.prepare()
        gen.impactOccurred(intensity: 0.9)
    }
}
