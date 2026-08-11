//
//  ContrastTests.swift
//  oneTests
//
//  V3Tokens metin renklerinin WCAG 2.1 AA kontrast eşiğini geçtiğini doğrular.
//
//  Neden test: `faintText` ve `ghostText` handoff'tan geldikleri hâlleriyle
//  (açık temada 3.26:1 ve 2.12:1) AA'nın altındaydı ve 10–11pt mono
//  etiketlerde kullanılıyorlardı — an sayısı, saat, kapsam gibi okunması
//  gereken bilgiler. Değerler düzeltildi; bu test bir daha sessizce
//  gerilemesinler diye duruyor.
//

import Testing
import SwiftUI
import UIKit
@testable import OneDailyBatuhan

// MARK: - WCAG hesabı

/// WCAG 2.1 relative luminance — https://www.w3.org/TR/WCAG21/#dfn-relative-luminance
private func relativeLuminance(hex: String) -> Double {
    let (r, g, b) = rgbComponents(hex: hex)
    func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
}

/// `#RRGGBB` → 0...1 aralığında bileşenler.
private func rgbComponents(hex: String) -> (Double, Double, Double) {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    let value = UInt32(s, radix: 16) ?? 0
    return (
        Double((value >> 16) & 0xFF) / 255.0,
        Double((value >> 8) & 0xFF) / 255.0,
        Double(value & 0xFF) / 255.0
    )
}

/// WCAG kontrast oranı — https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio
private func contrastRatio(_ a: String, _ b: String) -> Double {
    let la = relativeLuminance(hex: a)
    let lb = relativeLuminance(hex: b)
    let lighter = max(la, lb)
    let darker  = min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)
}

// MARK: - Token tablosu
//
// `V3Tokens` renkleri `UIColor { trait in ... }` ile üretiyor; test doğrudan
// hex'leri okuyor çünkü doğrulanan şey token'ın *değeri*, SwiftUI'nin trait
// çözümü değil. Buradaki hex'ler `V3Tokens.swift` ile birebir aynı olmalı —
// ayrışırlarsa `testTokenHexesMatchSource` yakalar.

private enum Theme: String {
    case light, dark

    /// Metnin üzerine çizildiği ekran zemini.
    var paper: String {
        switch self {
        case .light: return "#FBFAF7"
        case .dark:  return "#0C0C10"
        }
    }

    /// Kart / alan zemini — metinlerin çoğu bunun üzerinde.
    var surface: String {
        switch self {
        case .light: return "#FFFFFF"
        case .dark:  return "#16161C"
        }
    }
}

private struct TextToken {
    let name: String
    let light: String
    let dark: String

    func hex(_ theme: Theme) -> String {
        theme == .light ? light : dark
    }
}

private let textTokens: [TextToken] = [
    TextToken(name: "ink",       light: "#14141A", dark: "#F2F1EE"),
    TextToken(name: "mutedText", light: "#6B6B78", dark: "#9A9AA6"),
    TextToken(name: "faintText", light: "#6E6E7A", dark: "#868694"),
    TextToken(name: "ghostText", light: "#72727E", dark: "#80808E")
]

// MARK: - Tests

struct ContrastTests {

    /// WCAG 2.1 AA, normal boyutlu metin için 4.5:1 istiyor. v3'ün mono
    /// etiketleri 10–11pt, yani "büyük metin" istisnasına (3:1) girmiyorlar.
    private static let aaThreshold = 4.5

    @Test("Her metin token'ı her temada paper zemininde AA'yı geçiyor")
    func testTextTokensAgainstPaper() {
        for theme in [Theme.light, .dark] {
            for token in textTokens {
                let ratio = contrastRatio(token.hex(theme), theme.paper)
                #expect(
                    ratio >= Self.aaThreshold,
                    "\(token.name) (\(theme.rawValue)) paper üzerinde \(String(format: "%.2f", ratio)):1 — AA \(Self.aaThreshold):1 istiyor"
                )
            }
        }
    }

    @Test("Her metin token'ı her temada surface zemininde AA'yı geçiyor")
    func testTextTokensAgainstSurface() {
        for theme in [Theme.light, .dark] {
            for token in textTokens {
                let ratio = contrastRatio(token.hex(theme), theme.surface)
                #expect(
                    ratio >= Self.aaThreshold,
                    "\(token.name) (\(theme.rawValue)) surface üzerinde \(String(format: "%.2f", ratio)):1 — AA \(Self.aaThreshold):1 istiyor"
                )
            }
        }
    }

    /// Kontrast düzeltmesi üç kademeyi birbirine yaklaştırdı. Görsel
    /// hiyerarşinin tümüyle düzleşmediğini doğrula: koyudan açığa sıra
    /// bozulmasın (ink en koyu, ghost en açık).
    @Test("Metin hiyerarşisi korunuyor — ink > muted > faint > ghost")
    func testHierarchyOrdering() {
        for theme in [Theme.light, .dark] {
            let ratios = textTokens.map { contrastRatio($0.hex(theme), theme.paper) }
            for i in 1..<ratios.count {
                #expect(
                    ratios[i] < ratios[i - 1],
                    "\(textTokens[i].name) (\(theme.rawValue)) \(textTokens[i - 1].name)'den daha kontrastlı — hiyerarşi ters dönmüş"
                )
            }
        }
    }

    /// Testteki hex tablosu `V3Tokens` ile ayrışırsa test yanlış şeyi
    /// doğrular. Token'ın gerçek çözümlenmiş rengini iki trait altında
    /// okuyup karşılaştır.
    @Test("Test tablosu V3Tokens kaynağıyla uyuşuyor")
    func testTokenHexesMatchSource() {
        let live: [(String, Color)] = [
            ("ink",       V3Tokens.ink),
            ("mutedText", V3Tokens.mutedText),
            ("faintText", V3Tokens.faintText),
            ("ghostText", V3Tokens.ghostText)
        ]
        for (name, color) in live {
            guard let token = textTokens.first(where: { $0.name == name }) else {
                Issue.record("\(name) test tablosunda yok")
                continue
            }
            for (theme, style) in [(Theme.light, UIUserInterfaceStyle.light),
                                   (Theme.dark,  UIUserInterfaceStyle.dark)] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                let resolved = UIColor(color).resolvedColor(with: traits)
                let expected = UIColor(Color(hex: token.hex(theme)))
                #expect(
                    resolved.isApproximately(expected),
                    "\(name) (\(theme.rawValue)) V3Tokens'ta \(token.hex(theme)) değil — test tablosunu güncelle"
                )
            }
        }
    }
}

// MARK: - Yardımcı

private extension UIColor {
    /// 8-bit yuvarlamayı tolere eden renk karşılaştırması.
    func isApproximately(_ other: UIColor, tolerance: CGFloat = 1.5 / 255.0) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < tolerance
            && abs(g1 - g2) < tolerance
            && abs(b1 - b2) < tolerance
    }
}
