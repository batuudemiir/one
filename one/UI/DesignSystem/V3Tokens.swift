import SwiftUI
import UIKit

enum V3Tokens {

    // MARK: - Brand & neutrals

    /// Handoff "Renk — yüzeyler (light / dark)" tablosu. Işık değerleri
    /// değişmedi; koyu değerler tablodan birebir geldi. Tek marka vurgusu
    /// (`kor`) iki temada da aynı.
    private static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }

    static let kor        = Color(hex: "#FF3B1F")   // brand / accent — tema-bağımsız
    static let ink        = adaptive(light: "#14141A", dark: "#F2F1EE")   // birincil metin
    static let paper      = adaptive(light: "#FBFAF7", dark: "#0C0C10")   // ekran zemini
    static let surface    = adaptive(light: "#FFFFFF", dark: "#16161C")   // kart, alan
    static let wash       = adaptive(light: "#EFEDE7", dark: "#1D1D24")   // foto yeri, iç raylar
    static let hairline   = adaptive(light: "#E6E3DB", dark: "#24242C")   // kenar, pasif ilerleme
    static let dashed     = adaptive(light: "#D6D2C7", dark: "#2E2E38")   // boş gün çerçevesi
    // Metin renkleri — üçü de WCAG AA (4.5:1) üstünde, hem `paper` hem
    // `surface` zemininde.
    //
    // Handoff'un özgün `faintText` (#8A8A96 → 3.27:1) ve `ghostText`
    // (#A8A59C → 2.36:1) değerleri açık temada AA'yı geçmiyordu; ikisi de
    // 10–11pt mono etiketlerde kullanılıyor (an sayısı, saat, kapsam) —
    // yani dekoratif değil, okunması gereken içerik. Koyu temada `ghostText`
    // (#6E6E7C → 3.89:1) aynı sorunu yaşıyordu.
    //
    // Koyu temada belirleyici zemin `paper` değil `surface`: #16161C,
    // #0C0C10'dan açık olduğu için kart içi metinde kontrast düşüyor —
    // kartların mono meta satırı tam da orada. Değerler en kötü zemine göre
    // seçildi.
    //
    // Üç kademe arasındaki kontrast farkı daraldığı için hiyerarşi artık
    // ağırlıklı olarak boyut/tracking/uppercase ile taşınıyor.
    // Oranlar `ContrastTests` içinde doğrulanıyor — değiştirirken testi çalıştır.
    // (Parantezdeki sayılar: açık tema / koyu tema, en kötü zeminde.)
    static let mutedText  = adaptive(light: "#6B6B78", dark: "#9A9AA6")   // ikincil gövde     (5.03 / 6.47)
    static let faintText  = adaptive(light: "#6E6E7A", dark: "#868694")   // mikro etiket      (4.82 / 5.02)
    static let ghostText  = adaptive(light: "#72727E", dark: "#80808E")   // yer tutucu, sayaç (4.55 / 4.63)

    /// Tema-bağımsız sabitler — koyu zeminli yüzeyler (poster, kamera vizörü,
    /// hikaye modu) açık temada da koyu kalmalı.
    static let darkGround = Color(hex: "#0C0C10")
    static let darkText   = Color(hex: "#F2F1EE")
    static let darkMuted  = Color(hex: "#9A9AA6")

    // MARK: - Radii

    static let radiusChip: CGFloat    = 8
    static let radiusCard: CGFloat    = 16
    static let radiusPanel: CGFloat   = 20
    static let radiusTile: CGFloat    = 24
    static let radiusHero: CGFloat    = 32
    static let radiusCanvas: CGFloat  = 52
    static let radiusCapsule: CGFloat = 999

    // MARK: - Motion

    /// `cubic-bezier(.2,.9,.25,1)` — v3'ün tek easing eğrisi.
    static let easing = Animation.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.32)
    static let easingPress = Animation.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.12)
    static let easingChip = Animation.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.18)
    static let easingColor = Animation.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.30)
    static let easingSaved = Animation.timingCurve(0.2, 0.9, 0.25, 1.0, duration: 0.36)
}
