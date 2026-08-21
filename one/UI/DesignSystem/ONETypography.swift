//
//  ONETypography.swift
//  one
//
//  Tipografi — ergonomik View modifier'ları + Dynamic Type yardımcıları.
//
//  **Yüzlerin tek sahibi `V3Typography`.** Bu dosya bir zamanlar ikinci bir
//  tip ölçeğiydi ve kendi yüzlerini getiriyordu:
//
//      rol      | burası           | V3Typography
//      ---------|------------------|---------------------------
//      başlık   | SF Pro Bold      | Archivo ExtraBold Expanded
//      gövde    | DM Sans          | SF Pro Text
//      mono     | DM Sans SemiBold | SF Mono
//
//  Yani aynı rol, hangi ekranda olduğuna göre farklı bir yüzle çiziliyordu —
//  uygulamadaki en geniş görsel tutarsızlık buydu. Modifier'lar (`.bodySM()`,
//  `.displayMD()` …) 97 çağrı noktasında kullanıldığı için **isimleri
//  korundu**, yalnız arkaları `V3Typography`'ye bağlandı. DM Sans bundle'dan
//  çıktı.
//
//  Eşleme: 20pt ve üstü başlıklar Archivo (`display`), 17pt ve altı ile tüm
//  gövde SF Pro Text (`sans`), etiketler SF Mono (`mono`). 20pt eşiği v3
//  ekranlarının kendi pratiğinden geliyor — orada da `display()` 20'den
//  başlıyor.
//
//  Yeni kod doğrudan `V3Typography` çağırabilir; bu modifier'lar yalnız
//  kısaltma.
//

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

// MARK: — View modifier'ları

extension View {

    // ── Display (Archivo ExtraBold Expanded) ─────────────────────────────

    /// 44pt — aylık/yıllık özet hero, sinematik başlıklar
    func displayXXL() -> some View {
        self.font(V3Typography.display(44)).tracking(-0.9)
    }

    /// 40pt — splash, hero, wordmark
    func displayXL() -> some View {
        self.font(V3Typography.display(40)).tracking(-0.8)
    }

    /// 32pt — hero ekran başlığı
    func displayHero() -> some View {
        self.font(V3Typography.display(32)).tracking(-0.6)
    }

    /// 30pt — ana ekran başlığı
    func displayLG() -> some View {
        self.font(V3Typography.display(30, relativeTo: .title1)).tracking(-0.4)
    }

    /// 24pt — bölüm başlığı, modal başlığı
    func displayMD() -> some View {
        self.font(V3Typography.display(24, relativeTo: .title2)).tracking(-0.2)
    }

    /// 22pt — section başlığı, öne çıkan kart başlığı
    func displayLgAlt() -> some View {
        self.font(V3Typography.display(22, relativeTo: .title2)).tracking(-0.3)
    }

    /// 20pt — kart başlığı
    func displaySM() -> some View {
        self.font(V3Typography.display(20, relativeTo: .title3))
    }

    /// 17pt — alt başlık, navigation title.
    ///
    /// Tek `display*` istisnası: Archivo değil `sans`. Archivo ExtraBold
    /// Expanded bu ölçekte bir başlık değil bir duvar — v3 ekranları da
    /// 17pt'de `sans` kullanıyor.
    func displayXS() -> some View {
        self.font(V3Typography.sans(17, weight: .semibold, relativeTo: .headline))
    }

    // ── Body (SF Pro Text) ───────────────────────────────────────────────

    /// 18pt Medium — vurgulu body, lead body
    func bodyXL() -> some View {
        self.font(V3Typography.sans(18, weight: .medium))
    }

    /// 16pt Regular — birincil body
    func bodyLG() -> some View {
        self.font(V3Typography.sans(16))
    }

    /// 15pt Regular — standart body
    func bodyMD() -> some View {
        self.font(V3Typography.sans(15, relativeTo: .callout))
    }

    /// 14pt Regular — ikincil body
    func bodySM() -> some View {
        self.font(V3Typography.sans(14, relativeTo: .subheadline))
    }

    /// 13pt Regular — küçük body, ipucu
    func bodyXS() -> some View {
        self.font(V3Typography.sans(13, relativeTo: .footnote))
    }

    /// 15pt Medium — güçlü body
    func bodyMDMedium() -> some View {
        self.font(V3Typography.sans(15, weight: .medium, relativeTo: .callout))
    }

    /// 14pt Medium — güçlü secondary
    func bodySMMedium() -> some View {
        self.font(V3Typography.sans(14, weight: .medium, relativeTo: .subheadline))
    }

    /// 13pt Medium — küçük güçlü
    func bodyXSMedium() -> some View {
        self.font(V3Typography.sans(13, weight: .medium, relativeTo: .footnote))
    }

    // ── Body, semibold ───────────────────────────────────────────────────
    //
    // Ölçeğin **eksik yarısı**. `body*` regular, `body*Medium` medium
    // veriyordu; semibold rolü hiç yoktu — ama ekranlar 50 yerde semibold
    // gövde metni istiyor (satır başlıkları, buton etiketleri, isim satırı).
    //
    // Rol olmadığı için o 50 çağrı ham sayı yazıyordu, ve ham sayı yazan
    // her el kendi puntosunu seçiyordu: `sans` ailesi 21 ayrı punto
    // kullanır hâle gelmişti (10.5 / 11.5 / 12.5 / 13.5 / 14.5 …) —
    // markanın tanımladığı beş kademe yerine.
    //
    // Ölçeği polislemek değil, **tamamlamak** çözüyor: eksik rol, kaymanın
    // sebebiydi.

    /// 16pt SemiBold — vurgulu birincil satır
    func bodyLGSemibold() -> some View {
        self.font(V3Typography.sans(16, weight: .semibold))
    }

    /// 16pt Medium — orta vurgulu birincil satır
    func bodyLGMedium() -> some View {
        self.font(V3Typography.sans(16, weight: .medium))
    }

    /// 15pt SemiBold — satır başlığı, liste öğesi adı
    func bodyMDSemibold() -> some View {
        self.font(V3Typography.sans(15, weight: .semibold, relativeTo: .callout))
    }

    /// 14pt SemiBold — ikincil vurgu, kart içi başlık
    func bodySMSemibold() -> some View {
        self.font(V3Typography.sans(14, weight: .semibold, relativeTo: .subheadline))
    }

    /// 13pt SemiBold — küçük vurgu, çip etiketi
    func bodyXSSemibold() -> some View {
        self.font(V3Typography.sans(13, weight: .semibold, relativeTo: .footnote))
    }

    // ── Body, mikro (12pt) ───────────────────────────────────────────────
    //
    // Gövde ölçeğinin tabanı 13pt'ydi; ürünün altına bir kademe daha
    // ihtiyacı var (rozet, çip, sayaç yanı etiketi) ve o boşluk 11 / 11.5 /
    // 12 / 12.5 diye dört ayrı sayıyla dolduruluyordu.
    //
    // Neden `sans`, neden `mono` değil: 10–12pt mikro register'ı markada
    // mono — ama mono **veri** için (saat, sayaç, kapsam). Buradakiler
    // kelime ("Gönderildi", "Ekle", mood adı). 11pt'de mono'ya alınan bir
    // kelime dil gibi değil veri gibi okunuyor.

    /// 12pt Regular — mikro gövde
    func bodyMicro() -> some View {
        self.font(V3Typography.sans(12, relativeTo: .caption1))
    }

    /// 12pt Medium — mikro gövde, orta vurgu
    func bodyMicroMedium() -> some View {
        self.font(V3Typography.sans(12, weight: .medium, relativeTo: .caption1))
    }

    /// 12pt SemiBold — rozet, çip etiketi
    func bodyMicroSemibold() -> some View {
        self.font(V3Typography.sans(12, weight: .semibold, relativeTo: .caption1))
    }

    // ── Mono / etiket (SF Mono + tracking) ───────────────────────────────

    /// 12pt SemiBold + tracking — buton etiketi, büyük harf etiket
    func monoBase(tracking: CGFloat = 1.2) -> some View {
        self.font(V3Typography.mono(12, weight: .semibold)).tracking(tracking)
    }

    /// 11pt Medium + tracking — meta bilgi, sayaç
    func monoSM(tracking: CGFloat = 0.8) -> some View {
        self.font(V3Typography.mono(11, weight: .medium)).tracking(tracking)
    }

    /// 10pt Medium + tracking — küçük etiket, badge
    func monoLabel(tracking: CGFloat = 0.6) -> some View {
        self.font(V3Typography.mono(10, weight: .medium)).tracking(tracking)
    }

    /// 9pt Regular + tracking — mikro açıklama
    func monoMicro(tracking: CGFloat = 0.4) -> some View {
        self.font(V3Typography.mono(9)).tracking(tracking)
    }
}
