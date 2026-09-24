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

    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
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
        guard isEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    /// Fired at the start of the Save Ritual — mood'a özgü taktil dil.
    /// CoreHaptics ile tam zamanlama kontrolü — iOS cooldown bypass.
    ///
    /// intensity: 0.0–1.0 (güç)
    /// sharpness: 0.0 yumuşak/küt, 1.0 keskin/mekanik
    static func saveRitual(mood: V3Mood?) {
        guard isEnabled else { return }
        // Dokuz v3 mood'unun dokuzunun da kendi imzası var.
        //
        // Bu switch eskiden `ONEMood` (12 case) üzerindeydi ve iki yönde birden
        // kayıyordu: `sinirli` için desen tanımlıydı ama o mood v3 seçicisinden
        // **üretilemiyordu**; buna karşılık `coşkulu` hiç case'i olmadığı için
        // `default`'un nötr tıkına düşüyordu. Yani var olmayan bir duygunun
        // imzası varken, gerçek bir duygunun yoktu.
        //
        // `sinirli`nin ağır tek darbesi `coskulu`ya değil `gergin`e yakın
        // olduğu için ona verilmedi; `coskulu` taşan enerjiyi anlatan üç
        // vuruşluk kendi desenini aldı.
        switch mood {

        case .atesli:
            // Patlama + mini ikinci darbe — sert, keskin
            playPattern([
                (time: 0.00, intensity: 1.00, sharpness: 0.90),  // ana patlama
                (time: 0.12, intensity: 0.65, sharpness: 0.70),  // ikinci darbe
            ])

        case .coskulu:
            // Taşma — üç hızlanan vuruş, yukarı doğru
            playPattern([
                (time: 0.00, intensity: 0.55, sharpness: 0.45),
                (time: 0.10, intensity: 0.75, sharpness: 0.55),
                (time: 0.18, intensity: 0.95, sharpness: 0.65),
            ])

        case .enerjik:
            // Bounce çift — ana + echo, orta keskinlik
            playPattern([
                (time: 0.00, intensity: 0.80, sharpness: 0.60),
                (time: 0.14, intensity: 0.45, sharpness: 0.40),
            ])

        case .mutlu:
            // Tek, yumuşak ışık — düşük sharpness
            playPattern([
                (time: 0.00, intensity: 0.65, sharpness: 0.20),
            ])

        case .huzurlu:
            // Nefes gibi — çok hafif, küt
            playPattern([
                (time: 0.00, intensity: 0.30, sharpness: 0.10),
            ])

        case .odakli:
            // Su damlası — iki dalga, aralarında duraklama
            playPattern([
                (time: 0.00, intensity: 0.60, sharpness: 0.40),
                (time: 0.30, intensity: 0.30, sharpness: 0.20),
            ])

        case .gergin:
            // Hızlı çift darbe — gergin hissi
            playPattern([
                (time: 0.00, intensity: 0.70, sharpness: 0.75),
                (time: 0.15, intensity: 0.50, sharpness: 0.60),
            ])

        case .huzunlu:
            // Sade, hafif tık
            playPattern([
                (time: 0.00, intensity: 0.40, sharpness: 0.50),
            ])

        case .yorgun:
            // Minimal — barely there
            playPattern([
                (time: 0.00, intensity: 0.22, sharpness: 0.15),
            ])

        case .none:
            playPattern([
                (time: 0.00, intensity: 0.60, sharpness: 0.50),
            ])
        }
    }

    // MARK: - Selection

    /// Fired when a mood color is selected.
    /// Medium impact — meaningful but not jarring.
    static func moodSelected() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred(intensity: 0.65)
    }

    /// Fired when a feeling/emotion is selected.
    /// Softer than mood — a gentle acknowledgment.
    static func feelingSelected() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        gen.impactOccurred(intensity: 0.6)
    }

    // MARK: - Navigation

    /// Fired on bottom tab switch.
    /// Light selection feedback — non-intrusive.
    static func tabSwitch() {
        guard isEnabled else { return }
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }

    // MARK: - Social / Circle

    /// Fired when a friend is successfully connected.
    /// Strong, meaningful — marks a social connection.
    static func friendConnected() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: 0.8)
    }

    // MARK: - System Events

    /// Fired on midnight day reset (if app is open).
    /// Very soft — ambient, barely noticeable.
    static func dayReset() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        gen.impactOccurred(intensity: 0.3)
    }

    /// Fired on error or invalid action.
    static func error() {
        guard isEnabled else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.error)
    }

    // MARK: - Camera

    /// Fired at the moment a photo is captured.
    /// Heavy — mimics a physical shutter press.
    static func photoCapture() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.prepare()
        gen.impactOccurred(intensity: 0.9)
    }

    // MARK: - Micro-taps (yeni)

    /// Grid hücresi, segment, mini kart gibi seçim odaklı tıklamalar.
    /// `moodSelected`'dan hafif — arka planda hissedilen bir "onay".
    static func pick() {
        guard isEnabled else { return }
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }

    /// Toggle / switch / segment değişimi — tek net "tık".
    static func toggle() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: 0.45)
    }

    /// Birincil eylemin onayı — kaydet, kullan, gönder.
    ///
    /// `pick`'ten ağır, `saveRitual`'dan hafif: dokunuşun kendisini
    /// onaylıyor, kaydın tamamlandığını değil. Ritüel kendi sesini
    /// sonra çıkarıyor.
    static func commit() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred()
    }

    /// Kayıt ritüelinin mühür vuruşu (~0.45s).
    ///
    /// `saveRitual` → `saveRitualPeak` → **seal** → `songSaved` dizisinin
    /// üçüncü adımı. Sert ve kısa: mührün bastığı an.
    static func saveRitualSeal() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: 0.85)
    }

    /// Rozet açıldı — başarı bildirimi.


    /// Splash kapanıp uygulama açıldığında — yumuşak bir "hazır".
    static func appReady() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        gen.impactOccurred(intensity: 0.6)
    }

    /// Motoru ve üreteci önceden ısıtır — ateşlemez.
    ///
    /// Uygulama açılışındaki ilk haptik ölçülebilir biçimde geç geliyor.
    /// Splash bunu bekleme süresini kullanarak çözüyordu; o optimizasyon
    /// burada korunuyor (§1: girdi yolundaki her gecikmeyi denetle).
    static func warmUp() {
        guard isEnabled else { return }
        ensureEngine()
        UIImpactFeedbackGenerator(style: .soft).prepare()
    }

    /// Yakınlaştırma, sayfalama, chevron nav gibi geçici geçişler.
    static func nudge() {
        guard isEnabled else { return }
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred(intensity: 0.35)
    }

    // MARK: - Mood Bloom Reward

    /// Peak haptic pulse mid-ritual — light selection tick at ~0.35s.
    static func saveRitualPeak() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
