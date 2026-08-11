import SwiftUI

/// ONE v3 — brand constants.
/// Tek marka rengi: Kor. Duygu renkleri üründe yaşar, markada değil.
public enum ONEBrand {

    // MARK: Brand colours

    /// Kor — the single brand colour. Icon ground, primary press, active switch.
    public static let kor = Color(red: 1.0, green: 0.231, blue: 0.122)      // #FF3B1F
    /// Mürekkep — text and primary buttons.
    public static let ink = Color(red: 0.078, green: 0.078, blue: 0.102)    // #14141A
    /// Kemik — light ground and the wordmark on Kor.
    public static let bone = Color(red: 0.984, green: 0.980, blue: 0.969)   // #FBFAF7
    /// Boşluk — dark ground.
    public static let voidGround = Color(red: 0.047, green: 0.047, blue: 0.063) // #0C0C10

    // MARK: Mark geometry (v3 rules — do not change per-surface)

    /// Wordmark point size ÷ square side. v3 spec: `fontSize = side * 0.30`.
    /// "ONE" in Archivo wdth118/w800 is ≈ 2.6 × point size wide, so it fits inside.
    public static let wordmarkFontRatio: CGFloat = 0.30
    /// Legacy — kept for external callers that still read it. Do not use for new geometry.
    public static let glyphWidthRatio: CGFloat = 1.22
    /// Corner radius ÷ square side.
    public static let cornerRadiusRatio: CGFloat = 0.225
    /// Clear space around the mark ÷ square side.
    public static let clearSpaceRatio: CGFloat = 0.25
    /// Gap between mark and wordmark in the horizontal lockup ÷ square side.
    public static let lockupGapRatio: CGFloat = 0.34
    /// Wordmark tracking, in em. v3 spec: ≈ −0.035 em.
    public static let tracking: CGFloat = -0.035
    /// Smallest permitted rendered size, in points.
    public static let minimumSize: CGFloat = 24

    // MARK: Typography

    /// Display face. Bundle Archivo ExtraBold (wdth 118) (OFL) as "Archivo_ExtraBold_Expanded".
    /// Falls back to the heaviest system face if the font is missing.
    ///
    /// Dynamic Type'a `V3Typography.display` ile aynı tavandan ölçekleniyor —
    /// ikisi de aynı yüzü çiziyor, ayrışmasınlar.
    public static func display(_ size: CGFloat) -> Font {
        V3Typography.display(size)
    }
}
