import SwiftUI
import UIKit

/// v3 tipografi rollari — prototip Archivo (wdth118, w800) / Instrument Sans / DM Mono.
///
/// - `display`  → **Archivo ExtraBold Expanded** (bundle'daki `Archivo_ExtraBold_Expanded.ttf`)
///                yoksa system heavy default'a düşer
/// - `sans`     → SF Pro Text (Instrument Sans yerine — bundle edilmedi henüz)
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

    // MARK: - Sans (Instrument Sans substitute)

    static func sans(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: UIFont.TextStyle = .body
    ) -> Font {
        scaledSystemFont(size: size, weight: uiFontWeight(weight), textStyle: style)
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
