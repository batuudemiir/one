//
//  ONE2TokenTests.swift
//  oneTests
//
//  ONE 2.0 token'ları (ADR-002):
//  - tokens.json'daki her renk Swift'te var ve değeri aynı
//  - README'deki metin çiftleri iki temada 4.5:1+ (Increased Contrast dahil)
//  - line-strong ground ve surface üstünde 3:1+
//  tokens.json test bundle'ında: oneTests/Resources/tokens.json
//  (docs/one2/design-system/tokens.json'ın kopyası; docs değişince
//  kopya da güncellenir).
//
//  Kontrast hesabı `ContrastTests.swift`'teki `contrastRatio(_:_:)` ile.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

private final class BundleToken {}

private struct TokenFile: Decodable {
    struct ColorSection: Decodable { let tokens: [ColorToken] }
    struct ColorToken: Decodable {
        let name: String
        let value: [String: String]
    }
    let color: ColorSection
}

private func loadTokens() throws -> [String: [String: String]] {
    let url = try #require(Bundle(for: BundleToken.self).url(forResource: "tokens", withExtension: "json"))
    let file = try JSONDecoder().decode(TokenFile.self, from: Data(contentsOf: url))
    var out: [String: [String: String]] = [:]
    for t in file.color.tokens { out[t.name] = t.value }
    return out
}

/// `{brand}` gibi takma adları çözer.
private func resolve(_ value: String, theme: String, in all: [String: [String: String]]) -> String {
    guard value.hasPrefix("{"), value.hasSuffix("}") else { return value }
    let ref = String(value.dropFirst().dropLast())
    return all[ref]?[theme].map { resolve($0, theme: theme, in: all) } ?? value
}

/// README Renk: "Tüm metin çiftleri iki temada 4.5:1+".
private let textPairs: [(fg: String, bg: String)] = {
    var pairs: [(String, String)] = []
    for fg in ["ink", "ink-muted", "ink-faint", "success", "warning", "danger", "brand"] {
        for bg in ["ground", "surface", "raised"] { pairs.append((fg, bg)) }
    }
    pairs += [("on-primary", "primary"), ("on-brand", "brand"), ("on-brand-soft", "brand-soft")]
    pairs += (1...5).map { ("on-score-\($0)", "score-\($0)") }
    pairs += ["nese", "huzur", "enerji", "sevgi", "kaygi", "huzun", "ofke", "yorgun"].map { ("on-emo-\($0)", "emo-\($0)") }
    return pairs
}()

@MainActor
struct ONE2TokenTests {

    @Test("tokens.json'daki 47 rengin hepsi ONE2Palette'te, değerleri aynı")
    func everyJSONColorExistsInSwift() throws {
        let json = try loadTokens()
        #expect(json.count == 47)
        #expect(Set(json.keys) == Set(ONE2Palette.tokens.keys), "Swift ile JSON token kümeleri farklı")
        for (name, value) in json {
            for theme in ["gece", "gun"] {
                let expected = resolve(try #require(value[theme]), theme: theme, in: json).uppercased()
                let actual = ONE2Palette.hex(name, dark: theme == "gece").uppercased()
                #expect(actual == expected, "\(name) (\(theme)): Swift \(actual), JSON \(expected)")
            }
        }
    }

    @Test("Metin çiftleri iki temada ve Increased Contrast'ta 4.5:1+", arguments: [false, true])
    func textPairsPassAA(highContrast: Bool) {
        for dark in [true, false] {
            for pair in textPairs {
                let fg = ONE2Palette.hex(pair.fg, dark: dark, highContrast: highContrast)
                let bg = ONE2Palette.hex(pair.bg, dark: dark, highContrast: highContrast)
                let ratio = contrastRatio(fg, bg)
                #expect(ratio >= 4.5, "\(pair.fg) / \(pair.bg) (\(dark ? "gece" : "gün"), IC \(highContrast)): \(String(format: "%.2f", ratio)):1")
            }
        }
    }

    @Test("line-strong ground ve surface üstünde 3:1+")
    func lineStrongIsMeaningful() {
        for dark in [true, false] {
            for bg in ["ground", "surface"] {
                let ratio = contrastRatio(ONE2Palette.hex("line-strong", dark: dark), ONE2Palette.hex(bg, dark: dark))
                #expect(ratio >= 3, "line-strong / \(bg) (\(dark ? "gece" : "gün")): \(String(format: "%.2f", ratio)):1")
            }
        }
    }

    @Test("Increased Contrast: line → line-strong, ink-faint → ink-muted, diğerleri aynı")
    func increasedContrastMapping() {
        for dark in [true, false] {
            #expect(ONE2Palette.hex("line", dark: dark, highContrast: true) == ONE2Palette.hex("line-strong", dark: dark))
            #expect(ONE2Palette.hex("ink-faint", dark: dark, highContrast: true) == ONE2Palette.hex("ink-muted", dark: dark))
            #expect(ONE2Palette.hex("ink", dark: dark, highContrast: true) == ONE2Palette.hex("ink", dark: dark))
        }
    }

    @Test("Türkçe büyük harf: i → İ")
    func turkishUppercase() {
        #expect(ONE2Type.uppercased("genel içgörüler") == "GENEL İÇGÖRÜLER")
    }

    @Test("24pt üstü stiller ×1.25 ile sınırlı, diğerleri serbest")
    func dynamicTypeCaps() {
        #expect(ONE2Type.screenTitle.maximumPointSize == 55)
        #expect(ONE2Type.quote.maximumPointSize == 35)
        #expect(ONE2Type.title.maximumPointSize == nil)
        #expect(ONE2Type.body.maximumPointSize == nil)
    }
}
