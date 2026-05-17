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

import Foundation
import UIKit

actor ImageCache {
    static let shared = ImageCache()

    private let store: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 150          // ~150 images in RAM is plenty for feeds
        c.totalCostLimit = 48 * 1024 * 1024 // 48 MB ceiling
        return c
    }()

    /// Fetch image for URL — serves from cache if hit, otherwise loads and stores.
    /// Supports both remote (http/https) and local (file://) URLs. Returns nil on
    /// transport error or non-image data.
    func image(for url: URL) async -> UIImage? {
        if let cached = store.object(forKey: url as NSURL) {
            return cached
        }

        // file:// — local disk: read directly. URLSession ile cast `HTTPURLResponse`
        // başarısız olur (file response'u HTTPURLResponse değildir) ve fotoğraflar
        // önizlemede hiç görünmez. Local URL'leri ayrı ele alıyoruz.
        if url.isFileURL {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                return nil
            }
            store.setObject(image, forKey: url as NSURL, cost: Self.cacheCost(for: image))
            return image
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            // Remote sadece HTTP başarılı ise kabul edilir.
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                return nil
            }
            guard let image = UIImage(data: data) else { return nil }
            store.setObject(image, forKey: url as NSURL, cost: Self.cacheCost(for: image))
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
