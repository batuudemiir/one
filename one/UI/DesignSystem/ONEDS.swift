import SwiftUI

/// ONE — Design System v3
/// Kaynak: one-v3-design-system/foundations.md
///
/// NOT: Mevcut `ONETokens` namespace'i projede farklı bir palet kullanıyor ve
/// 141+ dosyaya yayılmış. Ad çakışmasını önlemek için v3 tokenları burada
/// `ONEDS` (Design System) altında yaşar. Yeni ekranlar ve v3 refaktorları
/// bu namespace'i kullanır. Migrasyon adım adım yapılmalı.
public enum ONEDS {

    // MARK: - Marka

    public static let kor        = Color(dsHex: 0xFF3B1F)
    public static let korPress   = Color(dsHex: 0xE42E13)   // açık tema
    public static let korPressDk = Color(dsHex: 0xFF5638)   // koyu tema
    public static let korWash    = Color(dsHex: 0xFFF0EC)
    public static let korDeep    = Color(dsHex: 0xB32210)

    public static let kobalt   = Color(dsHex: 0x2B4CF0)
    public static let murekkep = Color(dsHex: 0x14141A)
    public static let asit     = Color(dsHex: 0xC8F135)
    public static let iris     = Color(dsHex: 0x7B3BF5)

    // MARK: - Zeminler

    public enum Light {
        public static let bg       = Color(dsHex: 0xFBFAF7)
        public static let surface  = Color(dsHex: 0xFFFFFF)
        public static let surface2 = Color(dsHex: 0xF2F0EA)
        public static let canvas   = Color(dsHex: 0xEFEDE7)
        public static let line     = Color(dsHex: 0xE6E3DB)
        public static let ink      = Color(dsHex: 0x14141A)
        public static let ink2     = Color(dsHex: 0x6B6B78)
        public static let ink3     = Color(dsHex: 0xA8A59C)
    }

    public enum Dark {
        public static let bg       = Color(dsHex: 0x0C0C10)
        public static let surface  = Color(dsHex: 0x16161C)
        public static let surface2 = Color(dsHex: 0x1D1D24)
        public static let canvas   = Color(dsHex: 0x0C0C10)
        public static let line     = Color(dsHex: 0x26262F)
        public static let ink      = Color(dsHex: 0xF2F1EE)
        public static let ink2     = Color(dsHex: 0x9A9AA6)
        public static let ink3     = Color(dsHex: 0x6E6E7C)
    }

    // Şemaya duyarlı kısayollar — Assets.xcassets/Design/ altındaki dinamik renkler.
    public static let bg      = Color("one.bg")
    public static let surface = Color("one.surface")
    public static let surface2 = Color("one.surface2")
    public static let line    = Color("one.line")
    public static let ink     = Color("one.ink")
    public static let ink2    = Color("one.ink2")
    public static let ink3    = Color("one.ink3")

    // MARK: - Dokuz duygu

    /// Izgara sırası sabittir: satır = enerji, sütun = yön.
    public enum Mood: Int, CaseIterable, Identifiable {
        case atesli, coskulu, gergin
        case mutlu, enerjik, odakli
        case huzurlu, huzunlu, yorgun

        public var id: Int { rawValue }

        public var name: String {
            switch self {
            case .atesli:  return "Ateşli"
            case .coskulu: return "Coşkulu"
            case .gergin:  return "Gergin"
            case .mutlu:   return "Mutlu"
            case .enerjik: return "Enerjik"
            case .odakli:  return "Odaklı"
            case .huzurlu: return "Huzurlu"
            case .huzunlu: return "Hüzünlü"
            case .yorgun:  return "Yorgun"
            }
        }

        public var color: Color {
            switch self {
            case .atesli:  return Color(dsHex: 0xFF3B1F)
            case .coskulu: return Color(dsHex: 0xFF8A00)
            case .gergin:  return Color(dsHex: 0x8B2FD6)
            case .mutlu:   return Color(dsHex: 0xFFC300)
            case .enerjik: return Color(dsHex: 0xC8F135)
            case .odakli:  return Color(dsHex: 0x2B4CF0)
            case .huzurlu: return Color(dsHex: 0x00B58C)
            case .huzunlu: return Color(dsHex: 0x5C6BC0)
            case .yorgun:  return Color(dsHex: 0x6E7482)
            }
        }

        /// Bu rengin ÜSTÜNDE kullanılacak tek meşru metin rengi.
        public var ink: Color {
            switch self {
            case .atesli:  return Color(dsHex: 0x12060A)
            case .coskulu: return Color(dsHex: 0x1A0C00)
            case .gergin:  return Color(dsHex: 0xF6ECFF)
            case .mutlu:   return Color(dsHex: 0x1A1200)
            case .enerjik: return Color(dsHex: 0x141A00)
            case .odakli:  return Color(dsHex: 0xEAEEFF)
            case .huzurlu: return Color(dsHex: 0x04170F)
            case .huzunlu: return Color(dsHex: 0xEDEFFA)
            case .yorgun:  return Color(dsHex: 0xF2F3F5)
            }
        }
    }

    // MARK: - Tipografi

    /// Archivo ExtraBold Expanded. Bundle adı: "Archivo_ExtraBold_Expanded".
    /// Font kayıtlı değilse SwiftUI otomatik sistem fontuna düşer.
    public static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        let name = weight == .semibold ? "Archivo-SemiBoldExpanded" : "Archivo_ExtraBold_Expanded"
        return .custom(name, size: size)
    }

    public static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face: String
        switch weight {
        case .semibold: face = "InstrumentSans-SemiBold"
        case .medium:   face = "InstrumentSans-Medium"
        default:        face = "InstrumentSans-Regular"
        }
        return .custom(face, size: size)
    }

    public static func mono(_ size: CGFloat) -> Font {
        .custom("DMMono-Regular", size: size)
    }

    /// Ölçek — (boyut, satır yüksekliği katsayısı, tracking px)
    public enum TypeScale {
        public static let d1      = (size: 64.0, line: 0.92, track: -1.6)
        public static let d2      = (size: 40.0, line: 1.00, track: -0.9)
        public static let screen  = (size: 42.0, line: 0.95, track: -1.1)
        public static let section = (size: 34.0, line: 1.02, track: -0.9)
        public static let h1      = (size: 24.0, line: 1.25, track: -0.3)
        public static let h2      = (size: 21.0, line: 1.15, track: -0.6)
        public static let bodyL   = (size: 17.0, line: 1.55, track:  0.0)
        public static let body    = (size: 16.0, line: 1.50, track:  0.0)
        public static let bodyS   = (size: 14.0, line: 1.60, track:  0.0)
        public static let caption = (size: 13.0, line: 1.55, track:  0.0)
        public static let label   = (size: 11.0, line: 1.20, track:  1.4)
        public static let labelS  = (size: 10.0, line: 1.20, track:  1.5)
    }

    // MARK: - Boşluk, yarıçap, hareket

    public enum Space {
        public static let s1: CGFloat = 8
        public static let s2: CGFloat = 16
        public static let s3: CGFloat = 24
        public static let s4: CGFloat = 40
        public static let s5: CGFloat = 64
        public static let gutter: CGFloat = 24
        public static let target: CGFloat = 48
    }

    public enum Radius {
        public static let chip: CGFloat  = 8
        public static let card: CGFloat  = 14
        public static let panel: CGFloat = 20
        public static let mood: CGFloat  = 26
        public static let shell: CGFloat = 52
        public static let iconRatio: CGFloat = 0.225
    }

    public enum Motion {
        public static let press: Double  = 0.12
        public static let color: Double  = 0.30
        public static let screen: Double = 0.42
        public static let rise: Double   = 0.34
        public static let stagger: Double = 0.06
        public static let pressScale: CGFloat = 0.94
        public static let curve = Animation.timingCurve(0.2, 0.9, 0.25, 1)
    }

    // MARK: - Logo

    public enum Mark {
        /// Wordmark advance genişliği ÷ kare kenarı. Taşma kasıtlıdır.
        public static let glyphWidthRatio: CGFloat = 1.22
        /// Punto ÷ kare kenarı.
        public static let sizeRatio: CGFloat = 0.474
        /// Tracking, em cinsinden.
        public static let trackingEm: CGFloat = -0.035
        /// Köşe yarıçapı ÷ kare kenarı.
        public static let cornerRadiusRatio: CGFloat = 0.225
        /// "ONE" advance genişliği (tracking dahil), em cinsinden.
        public static let advanceEm: CGFloat = 2.572
    }
}

// MARK: - Yardımcı

public extension Color {
    /// Design System yardımcı hex init'i — mevcut `Color(hex:)` extension'ları ile çakışmaz.
    init(dsHex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((dsHex >> 16) & 0xFF) / 255,
            green: Double((dsHex >>  8) & 0xFF) / 255,
            blue:  Double( dsHex        & 0xFF) / 255,
            opacity: 1
        )
    }
}
