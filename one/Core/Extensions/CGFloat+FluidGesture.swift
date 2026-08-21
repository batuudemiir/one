//
//  CGFloat+FluidGesture.swift
//  one
//
//  Jest fiziği yardımcıları — Apple'ın "Designing Fluid Interfaces"
//  (WWDC 2018) örnek kodundan.
//
//  SwiftUI bunların bir kısmını hazır veriyor (`predictedEndTranslation`),
//  UIKit tarafında elle kurmak gerekiyor. İkisinin de aynı sayıları
//  üretmesi için tek kaynak burası.
//

import CoreGraphics
import UIKit

extension CGFloat {

    /// Sınırın ötesindeki bu aşımı, ilerledikçe artan bir dirençle küçültür.
    ///
    /// Neden: sürükleme sınırında `max(0, dy)` yazmak, ters yöne çekildiğinde
    /// sert bir duvar üretiyor ve o duvar "donmuş" okunuyor. Gerçek nesneler
    /// durmadan önce yavaşlar; burada da parmak sınırdan uzaklaştıkça eleman
    /// gitgide daha az takip ediyor. Sonuç: "hâlâ canlı, ama bu yönde
    /// gidecek bir şey yok."
    ///
    /// - Parameters:
    ///   - dimension: Kapsayıcının ilgili eksendeki boyutu (genelde ekran
    ///     yüksekliği/genişliği). Direncin ölçeğini bu belirliyor.
    ///   - constant: Apple'ın kullandığı 0.55. Küçüldükçe direnç sertleşir.
    /// - Returns: Ekrana uygulanacak, aşımdan her zaman küçük olan kayma.
    func rubberbanded(over dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
        guard dimension > 0 else { return 0 }
        return (self * dimension * constant) / (dimension + constant * abs(self))
    }

    /// Bu hızla bırakılan bir nesnenin, sürtünmeyle durana kadar alacağı
    /// ek yol. `self` = pt/sn cinsinden bırakma hızı.
    ///
    /// Kaydırma yavaşlamasının kullandığı üstel sönüm modeli. Fizik
    /// kitabındaki `v²/(2·a)` **değil** — Apple'ın gönderdiği bu.
    ///
    /// Kullanımı: `translation + velocity.projectedOffset()` → jestin
    /// gitmekte olduğu nokta. Kararı bırakma noktasına değil buna vermek,
    /// kısa ama sert bir fiskeyi de uzun ama yavaşlayan bir çekişi de
    /// doğru okuyor. SwiftUI'deki `predictedEndTranslation`'ın karşılığı.
    ///
    /// - Parameter decelerationRate: 0.998 normal kaydırma hissi,
    ///   0.99 daha çabuk duran.
    func projectedOffset(
        decelerationRate: CGFloat = UIScrollView.DecelerationRate.normal.rawValue
    ) -> CGFloat {
        guard decelerationRate < 1 else { return 0 }
        return (self / 1000) * decelerationRate / (1 - decelerationRate)
    }
}
