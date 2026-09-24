//
//  ONEButtonStyle.swift
//  one
//
//  Design System — Universal press-feedback button style.
//
//  `.buttonStyle(.plain)` iOS'un varsayılan fade'ini bastırıyor ama yerine
//  hiçbir dokunma geri bildirimi koymuyor. `ONEPressableButtonStyle`
//  görseli değiştirmeden sadece hafif bir scale (0.96) veriyor —
//  Photos/Instagram düzeyinde tanıdık iOS hissi.
//
//  Reduce Motion: scale atlanır, sadece opacity dip verilir.
//

import SwiftUI

struct ONEPressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Hit-test alanı: etiketin tam dörtgeni.
            //
            // Dolgusuz (yalnız `.stroke`'lu ya da hiç arka planı olmayan)
            // etiketlerde SwiftUI dokunuşu sadece Text gliflerine / Image
            // piksellerine düşürüyor; kapsülün içi "ölü" kalıyor ve buton
            // yalnız yazıya basınca çalışıyordu. Tek tek her çağrı noktasına
            // `.contentShape` eklemek yerine stile koyuyoruz: ONE'daki
            // dokunulabilir her şey zaten bu stili kullanıyor.
            .contentShape(Rectangle())
            .scaleEffect(
                (reduceMotion || !isEnabled) ? 1.0
                    : (configuration.isPressed ? ONEAnimation.buttonPressScale : 1.0)
            )
            .opacity(
                !isEnabled ? 0.55
                    : (configuration.isPressed ? 0.92 : 1.0)
            )
            .animation(
                configuration.isPressed
                    ? ONEAnimation.buttonPressAnimation
                    : ONEAnimation.buttonReleaseAnimation,
                value: configuration.isPressed
            )
    }
}

extension ButtonStyle where Self == ONEPressableButtonStyle {
    /// `.plain`'in görsel sadeliğini korur, üstüne hafif press feedback ekler.
    /// Tüm ONE buton call-site'ları için tercih edilen stil.
    static var onePressable: ONEPressableButtonStyle { .init() }
}

// MARK: - Buton dili: iki stil, iki rol
//
// ONE'da yalnızca iki buton stili vardır:
//
// 1. `.onePressable` — **dokunulabilir her şey.** Görünümü değiştirmez,
//    yalnız basma geri bildirimi ekler (scale + opacity, Reduce Motion ve
//    disabled farkında).
// 2. `V3PrimaryButton` — **birincil eylem.** Kapsül biçimini, dolgusunu ve
//    tipografisini kendisi çizer (`Devam`, `Kaydet`, `Gönder`).
//
// Buraya nasıl gelindi: bir ara altı ayrı stil vardı — `ONEPressableButtonStyle`,
// `V3CardPressStyle`, `ScaleButtonStyle`, `GlassButtonStyle`,
// `RecommendationCardButtonStyle`, `V3PrimaryButtonStyle`. İlk üçü aynı işi
// (scale 0.96) üç farklı eksiklikle yapıyordu: yalnız `ONEPressableButtonStyle`
// Reduce Motion ve `isEnabled` okuyordu. Kalan ikisi ölü koddu ve bir yerde de
// sistemin `.borderedProminent`'ı sızmıştı.
//
// **Kalan iş yok.** Uygulamadaki 90 `.buttonStyle(.plain)` çağrısının hepsi
// `.onePressable`'a çevrildi. Dönüşümün güvenli olmasının nedeni stilin
// katkısal olmasıydı: etiketi `.plain` ile birebir aynı çiziyor, üstüne
// yalnız basılı anın scale/opacity'sini ekliyor. Çevirmeden önce her çağrı
// noktasının etiketi tarandı; riskli desen (tam ekran perde, `Color.clear`
// etiket, kendi basma görselini zaten çizen buton) aranıp bulunamadı.
// `V3AvatarPicker` sınırdaki tek durumdu — orada seçildikten *sonra* bir pop
// var ama basma anında hiçbir şey yoktu; press dip + release pop doğru sıra,
// o yüzden o da çevrildi.
//
// Yeni bir buton yazarken `.plain` değil `.onePressable` kullan. `.plain`
// dokunma geri bildirimini tamamen kaldırır ve bu, dokunulabilir olduğu
// belli olmayan bir yüzey üretir.
