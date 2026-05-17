//
//  RichAttachmentFactory.swift
//  one
//
//  Mood rengi için runtime gradient PNG üretip `UNNotificationAttachment`
//  olarak döndürür. Cache edilmiş path'ler App Group Caches dizininde tutulur.
//

import UIKit
import UserNotifications

enum RichAttachmentFactory {

    /// Verilen hex renk için gradient thumbnail üretir ve attachment döndürür.
    /// Nil dönerse attachment eklemez — bildirim metinle gider.
    static func attachment(forMoodHex hex: String?, identifier: String) -> UNNotificationAttachment? {
        guard let hex, let color = UIColor(hexString: hex) else { return nil }
        guard let url = renderGradient(color: color, key: hex) else { return nil }
        return try? UNNotificationAttachment(
            identifier: identifier,
            url: url,
            options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
        )
    }

    private static func renderGradient(color: UIColor, key: String) -> URL? {
        let fm = FileManager.default
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("NotificationAttachments", isDirectory: true)
        guard let dir else { return nil }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let safeKey = key.replacingOccurrences(of: "#", with: "")
        let url = dir.appendingPathComponent("mood_\(safeKey).png")
        if fm.fileExists(atPath: url.path) { return url }

        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [color.cgColor,
                          color.withAlphaComponent(0.6).cgColor]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0.0, 1.0]
            ) else { return }
            cg.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }

        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - UIColor hex helper
private extension UIColor {
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
