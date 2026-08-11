//
//  ONETypography.swift
//  one
//
//  Design System — Brand Typography (v3)
//
//  Marka felsefesi:
//  • İki font eksenli sistem — SF Pro (Display) + DM Sans (Body/UI)
//  • Display: SF Pro — iOS native, güçlü, marka odaklı başlıklar
//  • Body/UI: DM Sans — sıcak geometrik sans, okunabilir, kişilikli
//  • Mono: DM Sans Medium — teknik meta veriler, etiketler
//
//  ─────────────────────────────────────────────────────────────
//  KURULUM: DM Sans fontunu projeye eklemek için:
//  1. Google Fonts'tan DM Sans'ı indir: fonts.google.com/specimen/DM+Sans
//  2. one/Resources/Fonts/ klasörüne şu dosyaları ekle:
//     - DMSans-Regular.ttf
//     - DMSans-Medium.ttf
//     - DMSans-SemiBold.ttf
//     - DMSans-Bold.ttf
//     - DMSans-Italic.ttf
//  3. ones.xcodeproj'a target membership ile ekle
//  4. Info.plist → UIAppFonts array'e ekle (aşağıdaki isimleri)
//  ─────────────────────────────────────────────────────────────

import SwiftUI
import UIKit

// MARK: — Dynamic Type Helpers

/// SF Pro için UIFontMetrics tabanlı ölçekleme.
/// Varsayılan boyutu korur, erişilebilirlik font boyutlarında ölçekler.
///
/// `V3Typography` ve `ONEBrand.display` de buradan geçiyor — v3 katmanı
/// eskiden düz `.system(size:)` döndürüyordu ve Dynamic Type'a hiç
/// uymuyordu. Tek ölçekleme noktası olsun diye `internal`.
func scaledSystemFont(
    size: CGFloat,
    weight: UIFont.Weight,
    textStyle: UIFont.TextStyle,
    maximumPointSize: CGFloat? = nil
) -> Font {
    let baseFont = UIFont.systemFont(ofSize: size, weight: weight)
    return Font(scaledUIFont(baseFont, textStyle: textStyle, maximumPointSize: maximumPointSize))
}

/// Hazır bir `UIFont`'u Dynamic Type'a göre ölçekler.
/// Custom yüzler (Archivo) için de aynı yol kullanılıyor.
func scaledUIFont(
    _ base: UIFont,
    textStyle: UIFont.TextStyle,
    maximumPointSize: CGFloat? = nil
) -> UIFont {
    let metrics = UIFontMetrics(forTextStyle: textStyle)
    if let maximumPointSize {
        return metrics.scaledFont(for: base, maximumPointSize: maximumPointSize)
    }
    return metrics.scaledFont(for: base)
}

/// SwiftUI `Font.Weight` → UIKit `UIFont.Weight`.
/// `Font.Weight` bir struct olduğu için `switch` edilemiyor; eşleşmeyen
/// bir değer gelirse `.regular`'a düşer.
func uiFontWeight(_ weight: Font.Weight) -> UIFont.Weight {
    switch weight {
    case .ultraLight: return .ultraLight
    case .thin:       return .thin
    case .light:      return .light
    case .medium:     return .medium
    case .semibold:   return .semibold
    case .bold:       return .bold
    case .heavy:      return .heavy
    case .black:      return .black
    default:          return .regular
    }
}

// MARK: — DM Sans Font Helper
// Dynamic Type desteği: Font.custom(_:size:relativeTo:) ile her font
// kullanıcının sistem font boyutuna göre ölçeklenir (iOS 14+).

private enum DMSans {
    static func regular(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        Font.custom("DMSans24pt-Regular", size: size, relativeTo: textStyle)
    }
    static func medium(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        Font.custom("DMSans24pt-Medium", size: size, relativeTo: textStyle)
    }
    static func semibold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .caption) -> Font {
        Font.custom("DMSans24pt-SemiBold", size: size, relativeTo: textStyle)
    }
    static func bold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        Font.custom("DMSans-Bold", size: size, relativeTo: textStyle)
    }
    static func italic(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        Font.custom("DMSans18pt-LightItalic", size: size, relativeTo: textStyle)
    }
}

// MARK: — Tip Ölçeği

enum ONETypography {

    // ── Display — SF Pro (büyük başlıklar, hero metinler) ─────────────────
    // Ekran başlıkları, hero metinler, bölüm başlıkları
    // SF Pro: iOS native güç, büyük boyutlarda editorial ve güçlü
    // Dynamic Type: relativeTo ile kullanıcının font büyüklüğüne göre ölçeklenir

    /// 44pt · Bold · Tight tracking  →  Monthly/Yearly summary hero, app-store cinematic titles
    /// Dynamic Type: `relativeTo: .largeTitle` ile accessibility5'te ~62pt'a yaklaşır
    static let displayXXL = scaledSystemFont(size: 44, weight: .bold, textStyle: .largeTitle)

    /// 40pt · Bold · Tight tracking  →  Splash, hero, wordmark
    static let displayXL = scaledSystemFont(size: 40, weight: .bold, textStyle: .largeTitle)

    /// 30pt · Semibold  →  Ana ekran başlığı (Yankı, Arşiv, Çevre…)
    static let displayLG = scaledSystemFont(size: 30, weight: .semibold, textStyle: .title1)

    /// 24pt · Semibold  →  Bölüm başlıkları, modal başlıklar
    static let displayMD = scaledSystemFont(size: 24, weight: .semibold, textStyle: .title2)

    /// 20pt · Medium  →  Kart başlığı, sayfa içi başlık
    static let displaySM = scaledSystemFont(size: 20, weight: .medium, textStyle: .title3)

    /// 17pt · Medium  →  Alt başlık, navigation title
    static let displayXS = scaledSystemFont(size: 17, weight: .medium, textStyle: .headline)

    /// 32pt · Bold  →  Hero ekran başlığı (Discover, Profile cover, büyük section)
    static let displayHero = scaledSystemFont(size: 32, weight: .bold, textStyle: .largeTitle)

    /// 22pt · Semibold  →  Section başlığı, prominent kart başlığı
    static let displayLgAlt = scaledSystemFont(size: 22, weight: .semibold, textStyle: .title2)

    // ── Body — DM Sans (okunabilir UI metni) ──────────────────────────────
    // DM Sans: sıcak geometrik sans, markaya kişilik katar
    // Body hiyerarşisinin tamamı DM Sans kullanır

    /// 18pt · Medium  →  Vurgulu body, prominent label, lead body
    static let bodyXL = DMSans.medium(18, relativeTo: .body)

    /// 16pt · Regular  →  Birincil body metni, açıklama
    static let bodyLG = DMSans.regular(16, relativeTo: .body)

    /// 15pt · Regular  →  Standart body, kart içeriği
    static let bodyMD = DMSans.regular(15, relativeTo: .callout)

    /// 14pt · Regular  →  İkincil body, liste itemları
    static let bodySM = DMSans.regular(14, relativeTo: .subheadline)

    /// 13pt · Regular  →  Küçük gövde, ipucu, yardım metni
    static let bodyXS = DMSans.regular(13, relativeTo: .footnote)

    /// 15pt · Medium  →  Güçlü body, öne çıkan bilgi
    static let bodyMDMedium = DMSans.medium(15, relativeTo: .callout)

    /// 14pt · Medium  →  Güçlü secondary, etiket içeriği
    static let bodySMMedium = DMSans.medium(14, relativeTo: .subheadline)

    /// 13pt · Medium  →  Küçük güçlü metin
    static let bodyXSMedium = DMSans.medium(13, relativeTo: .footnote)

    // ── Mono / Label — DM Sans (meta veriler, etiketler) ──────────────────
    // Buton etiketleri, bölüm başlıkları, meta bilgi
    // Monospaced yerine DM Sans Medium + letter-spacing kullanılır

    /// 12pt · SemiBold + tracking  →  Buton etiketi, büyük harf etiket
    static let monoBase = DMSans.semibold(12, relativeTo: .caption)

    /// 11pt · Medium + tracking  →  Meta bilgi, sayaç
    static let monoSM = DMSans.medium(11, relativeTo: .caption)

    /// 10pt · Medium + tracking  →  Küçük etiket, badge
    static let monoLabel = DMSans.medium(10, relativeTo: .caption2)

    /// 9pt · Regular + tracking  →  Mikro açıklama (mümkünse kaçın)
    static let monoMicro = DMSans.regular(9, relativeTo: .caption2)

    // Editorial (SF Serif) v3'te yok — Archivo display kullanılıyor.
    // Silinen: editorialXXL/XL/LG/MD. Yerine `ONEBrand.display(size)`.
}

// MARK: — View Modifier'lar

extension View {

    // ── Display (SF Pro) ──────────────────────────────────────────────────

    /// 44pt Bold — Monthly/Yearly summary hero, cinematic titles
    func displayXXL() -> some View {
        self.font(ONETypography.displayXXL)
            .tracking(-0.9)
    }

    /// 40pt Bold — splash, hero, wordmark
    func displayXL() -> some View {
        self.font(ONETypography.displayXL)
            .tracking(-0.8)
    }

    /// 30pt Semibold — ana ekran başlığı
    func displayLG() -> some View {
        self.font(ONETypography.displayLG)
            .tracking(-0.4)
    }

    /// 24pt Semibold — bölüm başlığı
    func displayMD() -> some View {
        self.font(ONETypography.displayMD)
            .tracking(-0.2)
    }

    /// 20pt Medium — kart başlığı
    func displaySM() -> some View {
        self.font(ONETypography.displaySM)
    }

    /// 17pt Medium — alt başlık, nav title
    func displayXS() -> some View {
        self.font(ONETypography.displayXS)
    }

    /// 32pt Bold — hero ekran başlığı
    func displayHero() -> some View {
        self.font(ONETypography.displayHero)
            .tracking(-0.6)
    }

    /// 22pt Semibold — section başlığı, prominent kart başlığı
    func displayLgAlt() -> some View {
        self.font(ONETypography.displayLgAlt)
            .tracking(-0.3)
    }

    // ── Body (DM Sans) ────────────────────────────────────────────────────

    /// 18pt Medium — vurgulu body, lead body
    func bodyXL() -> some View {
        self.font(ONETypography.bodyXL)
    }


    /// 16pt Regular — birincil body
    func bodyLG() -> some View {
        self.font(ONETypography.bodyLG)
    }

    /// 15pt Regular — standart body
    func bodyMD() -> some View {
        self.font(ONETypography.bodyMD)
    }

    /// 14pt Regular — ikincil body
    func bodySM() -> some View {
        self.font(ONETypography.bodySM)
    }

    /// 13pt Regular — küçük body, ipucu
    func bodyXS() -> some View {
        self.font(ONETypography.bodyXS)
    }

    /// 15pt Medium — güçlü body
    func bodyMDMedium() -> some View {
        self.font(ONETypography.bodyMDMedium)
    }

    /// 14pt Medium — güçlü secondary
    func bodySMMedium() -> some View {
        self.font(ONETypography.bodySMMedium)
    }

    /// 13pt Medium — küçük güçlü
    func bodyXSMedium() -> some View {
        self.font(ONETypography.bodyXSMedium)
    }

    // ── Mono / Label (DM Sans + tracking) ────────────────────────────────

    /// 12pt SemiBold + tracking — buton etiketi, büyük harf etiket
    func monoBase(tracking: CGFloat = 1.2) -> some View {
        self.font(ONETypography.monoBase)
            .tracking(tracking)
    }

    /// 11pt Medium + tracking — meta bilgi, sayaç
    func monoSM(tracking: CGFloat = 0.8) -> some View {
        self.font(ONETypography.monoSM)
            .tracking(tracking)
    }

    /// 10pt Medium + tracking — küçük etiket, badge
    func monoLabel(tracking: CGFloat = 0.6) -> some View {
        self.font(ONETypography.monoLabel)
            .tracking(tracking)
    }

    /// 9pt Regular + tracking — mikro açıklama
    func monoMicro(tracking: CGFloat = 0.4) -> some View {
        self.font(ONETypography.monoMicro)
            .tracking(tracking)
    }

    // Editorial serif modifier'ları (editorialXXL/XL/LG/MD) v3'te kaldırıldı.
    // Yerine: `.font(ONEBrand.display(size))` + `.tracking(...)`.
}
