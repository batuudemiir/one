import SwiftUI
import UIKit

/// v3 tipografi rollari — prototip Archivo (wdth118, w800) / Instrument Sans / DM Mono.
///
/// - `display`  → **Archivo ExtraBold Expanded** (bundle'daki `Archivo_ExtraBold_Expanded.ttf`)
///                yoksa system heavy default'a düşer
/// - `sans`     → **DM Sans** (`DMSans24pt-*` / `DMSans-Bold`)
///
///   Prototip Instrument Sans diyordu; o yüz bundle edilmedi. Yerine bir
///   dönem SF Pro Text kullanıldı, ama SF Pro bir yer tutucuydu ve ONE'ın
///   gövde metnini sistem yüzüne indiriyordu. DM Sans zaten bundle'da,
///   Instrument Sans'a SF Pro'dan çok daha yakın (ikisi de geometrik
///   grotesk) ve ONE'ın kendi tipografi notlarında "markaya kişilik katan
///   sıcak geometrik sans" diye tanımlı.
/// - `mono`     → SF Mono (DM Mono yerine)
///
/// **Dynamic Type:** üçü de `UIFontMetrics` üzerinden ölçekleniyor. Eskiden
/// düz `.system(size:)` / `.custom(size:)` dönüyorlardı, yani kullanıcının
/// metin boyutu ayarı v3 ekranlarında hiçbir şeyi değiştirmiyordu. Çağıranlar
/// değişmedi — 200'den fazla callsite tek noktadan ölçeklenir hale geldi.
enum V3Typography {

    /// Display başlıklar için ölçekleme tavanı — taban boyuta duyarlı.
    ///
    /// Gövde metni serbestçe ölçekleniyor (erişilebilirlik önce), ama display
    /// yüzü ekran başlıklarında kullanılıyor ve orada büyüme pahalı: An
    /// akışının 44pt'lik "Bugün nasılsın?" başlığı `.accessibility5`'te
    /// altındaki mood ızgarasını ve Devam butonunu ekran dışına itiyor —
    /// o ekran kaydırılamadığı için akış tıkanıyor.
    ///
    /// Küçük display kullanımları (kart başlıkları, 16–20pt) tam ölçeklenmeyi
    /// hak ediyor; ekranı dolduran 38–44pt başlıklar ölçülü büyümeli.
    private static func maxPointSize(for size: CGFloat) -> CGFloat {
        switch size {
        case ..<20: return size * 1.80
        case ..<32: return size * 1.50
        default:    return size * 1.25
        }
    }

    // MARK: - Display (Archivo ExtraBold Expanded)

    /// Not: `weight` parametresi Archivo tek weight bundle olduğu için etkisiz;
    /// caller'lar için geriye dönük uyumluluk açısından tutuldu.
    static func display(
        _ size: CGFloat,
        weight: Font.Weight = .heavy,
        relativeTo style: UIFont.TextStyle = .largeTitle
    ) -> Font {
        let base = UIFont(name: "Archivo_ExtraBold_Expanded", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .heavy)
        return Font(
            scaledUIFont(base, textStyle: style, maximumPointSize: maxPointSize(for: size))
        )
    }

    /// Ölçeklenmeyen display — **yalnız marka öğeleri** için.
    ///
    /// Kelime işareti okunacak bir metin değil, sabit oranları olan bir
    /// marka nesnesi; kullanıcının metin boyutu ayarıyla büyümemeli.
    /// Splash'te ayrıca `matchedGeometryEffect`'in kaynağı — boyutu
    /// oynarsa kabuğa devir geometrisi de oynar.
    ///
    /// Gövde metninde ASLA kullanma; `display(_:)` kullan.
    static func displayFixed(_ size: CGFloat) -> Font {
        if UIFont(name: "Archivo_ExtraBold_Expanded", size: size) != nil {
            return .custom("Archivo_ExtraBold_Expanded", fixedSize: size)
        }
        return .system(size: size, weight: .heavy)
    }

    // MARK: - Sans (Instrument Sans substitute)

    /// DM Sans PostScript adları. Bundle'da dört ağırlık var; ara değerler
    /// en yakın alt ağırlığa düşüyor (ör. `.heavy` → Bold), çünkü sentetik
    /// kalınlaştırma DM Sans'ın geometrisini bozuyor.
    private static func dmSansName(_ weight: Font.Weight) -> String {
        switch weight {
        case .medium:                     return "DMSans24pt-Medium"
        case .semibold:                   return "DMSans24pt-SemiBold"
        case .bold, .heavy, .black:       return "DMSans-Bold"
        default:                          return "DMSans24pt-Regular"
        }
    }

    static func sans(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: UIFont.TextStyle = .body
    ) -> Font {
        guard let base = UIFont(name: dmSansName(weight), size: size) else {
            // Bundle'da yoksa sistem yüzüne düş — metin çizilmemektense
            // yanlış yüzle çizilsin.
            return scaledSystemFont(size: size, weight: uiFontWeight(weight), textStyle: style)
        }
        return Font(scaledUIFont(base, textStyle: style))
    }

    /// Ölçeklenmeyen sans — **yalnız `ImageRenderer` ile görüntüye çizilen
    /// yüzeyler** (davet kartı, poster, story kartı) için.
    ///
    /// `monoFixed` ile aynı gerekçe: sabit tuvale çizilip dışarı paylaşılan
    /// bir kartta Dynamic Type erişilebilirlik değil bozulma. Bu rol
    /// olmadığı için export yüzeyleri `.font(.system(size:))` yazıyordu —
    /// yani ONE'ın dışarıya çıkan her kartı SF Pro ile, uygulamanın kendisi
    /// DM Sans ile çiziliyordu.
    ///
    /// Ekranda okunan hiçbir yerde kullanma; `sans(_:)` kullan.
    static func sansFixed(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if UIFont(name: dmSansName(weight), size: size) != nil {
            return .custom(dmSansName(weight), fixedSize: size)
        }
        return .system(size: size, weight: weight)
    }

    // MARK: - Hand (Caveat Brush)

    /// El yazısı — **dar kapsamlı dördüncü rol.**
    ///
    /// Yalnız an/gün kartındaki tarih-saat ve poster çıktıları. Gövde metni,
    /// buton, ekran başlığı, etiket: asla. Kural bu kadar sert, çünkü el
    /// yazısı bir okuma yüzü değil, bir **ton** — iki yerde kullanılırsa
    /// karakter, beş yerde kullanılırsa gürültü olur.
    ///
    /// Neden var: an kartı bir kayıt fişi değil, birinin yaşadığı bir an.
    /// Archivo ve SF Mono ikisi de "sistem konuşuyor" diyor; buradaki tek
    /// öğe "sen yazmışsın" demeli.
    ///
    /// Caveat Brush (SIL OFL 1.1, `CaveatBrush-Regular.ttf`). Bundle'da
    /// yoksa system rounded semibold'a düşüyor — el yazısı değil ama en
    /// azından geri kalanından ayrışan bir yüz.
    ///
    /// Ölçekleme `display` ile aynı tavanlarda: bu yüz de büyük punto
    /// kullanılıyor ve serbest bıraksak kartı taşırırdı.
    static func hand(
        _ size: CGFloat,
        relativeTo style: UIFont.TextStyle = .title1
    ) -> Font {
        let base = UIFont(name: "CaveatBrush-Regular", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .semibold)
        return Font(
            scaledUIFont(base, textStyle: style, maximumPointSize: maxPointSize(for: size))
        )
    }

    // MARK: - Mono (DM Mono substitute)

    /// Mono etiketler 10–11pt, uppercase + tracking'li mikro bilgi (sayaç,
    /// saat, kapsam). `.caption1` metriği bunları gövde metninden daha ölçülü
    /// büyütüyor — yine de büyüyor, çünkü okunması gereken içerik.
    static func mono(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: UIFont.TextStyle = .caption1
    ) -> Font {
        let base = UIFont.monospacedSystemFont(ofSize: size, weight: uiFontWeight(weight))
        return Font(scaledUIFont(base, textStyle: style))
    }

    /// Ölçeklenmeyen mono — **yalnız `ImageRenderer` ile görüntüye çizilen
    /// yüzeyler** (poster, story kartı) için.
    ///
    /// O yüzeyler sabit bir tuvale çiziliyor (ör. 1080×1920) ve dışarı
    /// paylaşılıyor. Dynamic Type orada bir erişilebilirlik kazancı değil,
    /// bir bozulma: metin boyutunu büyütmüş bir kullanıcının paylaştığı
    /// poster, tuvale sığmayan bir yazıyla çıkıyor.
    ///
    /// Ekranda okunan hiçbir yerde kullanma; `mono(_:)` kullan.
    static func monoFixed(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font(UIFont.monospacedSystemFont(ofSize: size, weight: uiFontWeight(weight)))
    }
}

extension View {
    /// Micro-label — uppercase + tracked mono, handoff'ta her yerde tekrar ediyor.
    func v3MicroLabel(_ tracking: CGFloat = 1.4) -> some View {
        self
            .font(V3Typography.mono(11, weight: .regular))
            .tracking(tracking)
            .textCase(.uppercase)
    }
}
