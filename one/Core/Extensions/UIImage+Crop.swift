//
//  UIImage+Crop.swift
//  one
//
//  v3: story kart 9:16, arşiv photoBlock 250pt tall.
//  Foto seçilir seçilmez `centerCropped(toAspect:)` ile normalize edilir —
//  tüm görüntüleyiciler tutarlı çerçeveleme kullansın.
//

import UIKit

extension UIImage {

    /// Görseli hedef aspect ratio'ya (width / height) center-crop eder.
    /// Nil dönerse (nadir), caller orijinali kullanır.
    ///
    /// - Parameter aspect: hedef `width / height` (örn. 9:16 = 0.5625).
    func centerCropped(toAspect aspect: CGFloat) -> UIImage? {
        guard aspect > 0 else { return nil }
        // Görselin doğru yönelimini ("up") uygula — EXIF orientation'lı
        // kaynaklar (kamera roll fotoğrafları) yanlış crop üretmesin.
        let source = normalizedOrientation()
        guard let cg = source.cgImage else { return nil }

        let srcW = CGFloat(cg.width)
        let srcH = CGFloat(cg.height)
        let srcAspect = srcW / srcH

        let cropRect: CGRect
        if srcAspect > aspect {
            // Kaynak daha geniş — yanları kırp (yatay merkez).
            let newW = srcH * aspect
            let x = (srcW - newW) / 2
            cropRect = CGRect(x: x, y: 0, width: newW, height: srcH)
        } else {
            // Kaynak daha uzun/dar — üst/alt kırp (dikey merkez).
            let newH = srcW / aspect
            let y = (srcH - newH) / 2
            cropRect = CGRect(x: 0, y: y, width: srcW, height: newH)
        }

        guard let cropped = cg.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: source.scale, orientation: .up)
    }

    /// EXIF orientation'ı bake ederek `.up` yönelimli yeni bir görsel döner.
    /// `cropping(to:)` pixel-space çalışır ve `imageOrientation`'ı yok sayar;
    /// önceden normalize etmezsek portrait iPhone fotoğrafları yan yatık çıkar.
    private func normalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
