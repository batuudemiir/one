//
//  ImageCache.swift
//  one
//
//  Lightweight in-memory image cache (Faz 3.3, 2026-04-26).
//  Backed by NSCache — automatic memory pressure handling, thread-safe via actor.
//
//  Usage: prefer `CachedAsyncImage` (drop-in AsyncImage replacement) instead of
//  touching this directly.
//
//  2026-08 — decode yolu düzeltildi. Önceden `UIImage(data:)` kullanılıyordu;
//  bunun iki maliyeti vardı:
//
//  1. `UIImage(data:)` çözmeyi (decode) **ilk çizime** erteler. Yani JPEG'i
//     piksele açma işi, actor'ın arka planında değil, kare çizilirken main
//     thread'de oluyordu — kaydırma sırasındaki takılmanın klasik nedeni.
//  2. Tam çözünürlük saklanıyordu. Bir iPhone fotoğrafı 4032×3024, yani
//     4032×3024×4 ≈ 48.7 MB — cache'in `totalCostLimit`'inin tamamı. Tek
//     fotoğraf tüm cache'i doldurup boşaltıyordu, `countLimit = 150` hiç
//     devreye girmiyordu.
//
//  Artık ImageIO ile hedef boyuta indirgenip **hemen** çözülüyor.
//

import Foundation
import UIKit
import ImageIO

actor ImageCache {
    static let shared = ImageCache()

    /// Varsayılan indirgeme hedefi — uzun kenar, piksel.
    ///
    /// Uygulamadaki en büyük görsel yüzeyi tam ekran fotoğraf görüntüleyici;
    /// o bile bir telefon ekranının yatay çözünürlüğünden fazlasını
    /// gösteremiyor (iPhone 16 Pro: 1206 px). 1400 hem oradaki en kötü hâli
    /// karşılıyor hem de tipik bir fotoğrafı ~5 MB'a indiriyor — 48 MB'lık
    /// tavana artık gerçekten onlarca görsel sığıyor.
    ///
    /// Avatar ya da kart küçük resmi çizen çağıranlar daha küçük bir değer
    /// geçerek daha da kazanabilir; farklı boyutlar ayrı ayrı saklanıyor.
    static let defaultMaxPixelSize: CGFloat = 1400

    /// Liste satırlarındaki küçük kareler (albüm kapağı, avatar — 40–60 pt).
    /// @3x'te bile 180 px; 240 payla yeter. Bunlar kaydırılan yüzeylerde
    /// olduğu için en çok kazanan çağrılar.
    static let thumbnailMaxPixelSize: CGFloat = 240

    private let store: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 150          // ~150 images in RAM is plenty for feeds
        c.totalCostLimit = 48 * 1024 * 1024 // 48 MB ceiling
        return c
    }()

    /// Fetch image for URL — serves from cache if hit, otherwise loads and stores.
    /// Supports both remote (http/https) and local (file://) URLs. Returns nil on
    /// transport error or non-image data.
    ///
    /// - Parameter maxPixelSize: indirgeme hedefi (uzun kenar, piksel).
    ///   Aynı URL farklı boyutlarda ayrı girdiler olarak saklanır.
    func image(for url: URL, maxPixelSize: CGFloat = ImageCache.defaultMaxPixelSize) async -> UIImage? {
        let key = Self.cacheKey(url: url, maxPixelSize: maxPixelSize)
        if let cached = store.object(forKey: key) {
            return cached
        }

        // file:// — local disk: read directly. URLSession ile cast `HTTPURLResponse`
        // başarısız olur (file response'u HTTPURLResponse değildir) ve fotoğraflar
        // önizlemede hiç görünmez. Local URL'leri ayrı ele alıyoruz.
        if url.isFileURL {
            guard let data = try? Data(contentsOf: url),
                  let image = Self.decode(data: data, maxPixelSize: maxPixelSize) else {
                return nil
            }
            store.setObject(image, forKey: key, cost: Self.cacheCost(for: image))
            return image
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            // Remote sadece HTTP başarılı ise kabul edilir.
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                return nil
            }
            guard let image = Self.decode(data: data, maxPixelSize: maxPixelSize) else { return nil }
            store.setObject(image, forKey: key, cost: Self.cacheCost(for: image))
            return image
        } catch {
            return nil
        }
    }

    /// Manual eviction (e.g. on logout / low memory warning).
    func clear() {
        store.removeAllObjects()
    }

    // MARK: - Private helpers

    private static func cacheKey(url: URL, maxPixelSize: CGFloat) -> NSString {
        "\(url.absoluteString)|\(Int(maxPixelSize))" as NSString
    }

    /// Veriyi hedef boyuta indirger ve **burada** çözer.
    ///
    /// `kCGImageSourceShouldCacheImmediately` bu işin kalbi: çözme actor'ın
    /// arka planında bitiyor, çizim anında main thread'e iş kalmıyor.
    /// `…WithTransform` EXIF yönünü uygular, yani portre çekilmiş fotoğraflar
    /// yan dönmez.
    ///
    /// İndirgeme başarısız olursa (bozuk veri, desteklenmeyen biçim) tam
    /// çözünürlüklü `UIImage(data:)`'ya düşülüyor — görsel hiç görünmemektense
    /// pahalı görünsün.
    private static func decode(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(
            data as CFData, sourceOptions as CFDictionary
        ) else {
            return UIImage(data: data)
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbnailOptions as CFDictionary
        ) else {
            return UIImage(data: data)
        }
        // scale: 1 — `cgImage` zaten piksel boyutunda ve yönü düzeltilmiş.
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    /// Pixel-based cost: gerçek bellek kullanımı (w × h × 4 bytes RGBA).
    /// data.count (compressed) yerine rendered pixel size kullanılır —
    /// bu sayede NSCache'in totalCostLimit MB hesabı gerçekçi kalır.
    private static func cacheCost(for image: UIImage) -> Int {
        let scale = image.scale
        let w = Int(image.size.width  * scale)
        let h = Int(image.size.height * scale)
        return w * h * 4   // 4 bytes per pixel (RGBA)
    }
}
