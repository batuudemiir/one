//
//  QRCodeGenerator.swift
//  one
//
//  Tiny wrapper around CIFilter("CIQRCodeGenerator") for embedding
//  invite deep links in share cards.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {

    /// Build a UIImage QR code for the given string at a target pixel size.
    /// Returns nil only if CoreImage fails to produce an image — callers
    /// should fall back gracefully (hide the QR, keep the text code).
    static func generate(from text: String, size: CGFloat = 160) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // tolerate 30% occlusion

        guard let ciImage = filter.outputImage else { return nil }

        let scaleX = size / ciImage.extent.size.width
        let scaleY = size / ciImage.extent.size.height
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Convenience: invite URL → QR. Uses the universal link so scanners
    /// route through the web fallback if the app isn't installed.
    static func inviteQR(code: String, size: CGFloat = 160) -> UIImage? {
        let url = "https://one.forvibe.app/invite?code=\(code.uppercased())"
        return generate(from: url, size: size)
    }
}
