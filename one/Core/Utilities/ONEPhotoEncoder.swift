//
//  ONEPhotoEncoder.swift
//  one
//
//  An fotoğrafının tek kodlama noktası.
//
//  Neden var: fotoğraflar Core Data'ya **inline** yazılıyor (`photoData`) ve
//  oradan CloudKit'e senkron oluyor. Kodlama şu ana kadar üç ayrı yerde
//  `jpegData(compressionQuality: 0.7)` olarak, **downsample olmadan**
//  yapılıyordu — yani kameradan ne çıktıysa tam çözünürlükte gidiyordu.
//
//  Günde birkaç an tutan bir kullanıcıda bu hızla yüz MB'lara çıkıyor:
//  store dosyası şişiyor, ilk senkron uzuyor, düşük bağlantıda arşiv geç
//  açılıyor. Üstelik bu çözünürlüğün karşılığı yok — en büyük tüketici
//  1080×1920'lik story çıktısı.
//
//  Tavan: **uzun kenar 1920px, kalite 0.7.** Story için fazlasıyla yeterli,
//  an başına ~300-500 KB. Zaten küçük görseller büyütülmüyor.
//

import UIKit

enum ONEPhotoEncoder {

    /// Uzun kenar tavanı. 1080×1920 story çıktısını beslemeye yeter.
    static let maxDimension: CGFloat = 1920

    /// JPEG kalitesi. 0.7 bu boyutlarda gözle ayırt edilebilir bir kayıp
    /// vermiyor; 0.8'e çıkarmak dosyayı ~%40 büyütüyor.
    static let quality: CGFloat = 0.7

    /// Ölçekle + JPEG'e kodla. Zaten tavanın altındaysa yeniden çizmez,
    /// doğrudan kodlar.
    static func encode(_ image: UIImage) -> Data? {
        downscaled(image).jpegData(compressionQuality: quality)
    }

    /// Uzun kenarı `maxDimension`'a indirilmiş kopya. Oran korunur.
    static func downscaled(_ image: UIImage) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let target = CGSize(width: (size.width * scale).rounded(),
                            height: (size.height * scale).rounded())

        // `scale: 1` bilinçli: hedef piksel boyutu tam olarak `target` olsun.
        // Cihazın ekran ölçeği devreye girerse 3x bir telefonda üç katı
        // piksel üretir ve tavan hiçbir şey yapmamış olur.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
