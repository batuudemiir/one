//
//  ONE2Color.swift
//  ONE 2.0
//
//  ONE 2.0 renk token'ları (docs/one2/design-system/tokens.json, ADR-002).
//  47 rengin hepsi, JSON'daki adların camelCase hâliyle. İki tema: `gece`
//  (koyu, varsayılan) ve `gun` (açık); tema sistemden gelir, renkler
//  `UIColor` dynamic provider ile çözülür.
//
//  Increased Contrast (README Erişilebilirlik): `line` → `lineStrong`,
//  `inkFaint` → `inkMuted`. Başka token değişmez; ikisi de zaten AA üstünde.
//
//  Değerler yalnız `ONE2Palette`'te yazılı; `ONE2TokenTests` onları
//  tokens.json ile birebir karşılaştırır.
//

import SwiftUI
import UIKit

/// Bir token'ın iki temadaki ham değeri: `#RRGGBB` ya da `#RRGGBBAA`.
nonisolated struct ONE2Hex: Hashable, Sendable {
    let gece: String
    let gun: String
}

/// Ham değer tablosu. Anahtarlar tokens.json adlarıdır (`line-strong`).
nonisolated enum ONE2Palette {

    static let tokens: [String: ONE2Hex] = [
        // Nötrler
        "ground":        ONE2Hex(gece: "#000000", gun: "#F4F4F2"),
        "surface":       ONE2Hex(gece: "#141416", gun: "#FFFFFF"),
        "raised":        ONE2Hex(gece: "#1E1E21", gun: "#EAEAE7"),
        "glass":         ONE2Hex(gece: "#2A2A2ECC", gun: "#FFFFFFCC"),
        "line":          ONE2Hex(gece: "#26262A", gun: "#E2E2DE"),
        "line-strong":   ONE2Hex(gece: "#66666E", gun: "#8A8A90"),
        "ink":           ONE2Hex(gece: "#F4F4F5", gun: "#111113"),
        "ink-muted":     ONE2Hex(gece: "#A3A3AA", gun: "#55555C"),
        "ink-faint":     ONE2Hex(gece: "#85858D", gun: "#66666E"),
        // Eylem
        "primary":       ONE2Hex(gece: "#E8E8EA", gun: "#111113"),
        "on-primary":    ONE2Hex(gece: "#111113", gun: "#F4F4F5"),
        // Tek vurgu
        "brand":         ONE2Hex(gece: "#9AA6FF", gun: "#2438C8"),
        "brand-soft":    ONE2Hex(gece: "#232B57", gun: "#E4E7FB"),
        "on-brand":      ONE2Hex(gece: "#0F1218", gun: "#FFFFFF"),
        "on-brand-soft": ONE2Hex(gece: "#C9CFFF", gun: "#2438C8"),
        "focus":         ONE2Hex(gece: "#9AA6FF", gun: "#2438C8"),
        // Ritüel
        "sabah":         ONE2Hex(gece: "#F2B84B", gun: "#E0A12C"),
        "aksam":         ONE2Hex(gece: "#7D8BE0", gun: "#33407A"),
        // Durum
        "success":       ONE2Hex(gece: "#5CC08C", gun: "#2A7550"),
        "warning":       ONE2Hex(gece: "#F0A640", gun: "#9A5B00"),
        "danger":        ONE2Hex(gece: "#FF8577", gun: "#B8342A"),
        // Mood skoru 1–5
        "score-1":       ONE2Hex(gece: "#5B6CCB", gun: "#2E3F8F"),
        "score-2":       ONE2Hex(gece: "#8F99D0", gun: "#7883BD"),
        "score-3":       ONE2Hex(gece: "#9A9C94", gun: "#A6A89F"),
        "score-4":       ONE2Hex(gece: "#E9B650", gun: "#E9B650"),
        "score-5":       ONE2Hex(gece: "#F08A2E", gun: "#E07A1F"),
        "on-score-1":    ONE2Hex(gece: "#FFFFFF", gun: "#FFFFFF"),
        "on-score-2":    ONE2Hex(gece: "#15181D", gun: "#15181D"),
        "on-score-3":    ONE2Hex(gece: "#15181D", gun: "#15181D"),
        "on-score-4":    ONE2Hex(gece: "#15181D", gun: "#15181D"),
        "on-score-5":    ONE2Hex(gece: "#15181D", gun: "#15181D"),
        // Duygu aileleri
        "emo-nese":      ONE2Hex(gece: "#E9AE2E", gun: "#E3A21A"),
        "emo-huzur":     ONE2Hex(gece: "#6FA684", gun: "#5E8F71"),
        "emo-enerji":    ONE2Hex(gece: "#E97650", gun: "#E0643E"),
        "emo-sevgi":     ONE2Hex(gece: "#DB7D9B", gun: "#CF6A8A"),
        "emo-kaygi":     ONE2Hex(gece: "#A27FBA", gun: "#7D5596"),
        "emo-huzun":     ONE2Hex(gece: "#7394C8", gun: "#46679A"),
        "emo-ofke":      ONE2Hex(gece: "#D0654D", gun: "#A93F2C"),
        "emo-yorgun":    ONE2Hex(gece: "#8D96A3", gun: "#687080"),
        "on-emo-nese":   ONE2Hex(gece: "#15181D", gun: "#15181D"),
        "on-emo-huzur":  ONE2Hex(gece: "#15181D", gun: "#15181D"),
        "on-emo-enerji": ONE2Hex(gece: "#15181D", gun: "#15181D"),
        "on-emo-sevgi":  ONE2Hex(gece: "#15181D", gun: "#15181D"),
        "on-emo-kaygi":  ONE2Hex(gece: "#15181D", gun: "#FFFFFF"),
        "on-emo-huzun":  ONE2Hex(gece: "#15181D", gun: "#FFFFFF"),
        "on-emo-ofke":   ONE2Hex(gece: "#15181D", gun: "#FFFFFF"),
        "on-emo-yorgun": ONE2Hex(gece: "#15181D", gun: "#FFFFFF"),
    ]

    /// Increased Contrast açıkken yerine geçen token (README Erişilebilirlik).
    static let increasedContrast: [String: String] = [
        "line": "line-strong",
        "ink-faint": "ink-muted",
    ]

    /// `highContrast`: sistem Increased Contrast açık mı.
    static func hex(_ name: String, dark: Bool, highContrast: Bool = false) -> String {
        let resolved = highContrast ? (increasedContrast[name] ?? name) : name
        guard let value = tokens[resolved] else {
            assertionFailure("ONE2Palette: bilinmeyen token \(resolved)")
            return "#FF00FF"
        }
        return dark ? value.gece : value.gun
    }

    /// `#RRGGBB` / `#RRGGBBAA` → 0...1 bileşenler.
    static func rgba(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let value = UInt64(s, radix: 16) ?? 0
        if s.count == 8 {
            return (Double((value >> 24) & 0xFF) / 255, Double((value >> 16) & 0xFF) / 255,
                    Double((value >> 8) & 0xFF) / 255, Double(value & 0xFF) / 255)
        }
        return (Double((value >> 16) & 0xFF) / 255, Double((value >> 8) & 0xFF) / 255,
                Double(value & 0xFF) / 255, 1)
    }
}

enum ONE2Color {

    // MARK: Nötrler
    static let ground = color("ground")
    static let surface = color("surface")
    static let raised = color("raised")
    static let glass = color("glass")
    static let line = color("line")
    static let lineStrong = color("line-strong")
    static let ink = color("ink")
    static let inkMuted = color("ink-muted")
    static let inkFaint = color("ink-faint")

    // MARK: Eylem
    static let primary = color("primary")
    static let onPrimary = color("on-primary")

    // MARK: Tek vurgu — ekran başına bir yer
    static let brand = color("brand")
    static let brandSoft = color("brand-soft")
    static let onBrand = color("on-brand")
    static let onBrandSoft = color("on-brand-soft")
    static let focus = color("focus")

    // MARK: Ritüel — metin rengi değil
    static let sabah = color("sabah")
    static let aksam = color("aksam")

    // MARK: Durum — her zaman bir kelimeyle
    static let success = color("success")
    static let warning = color("warning")
    static let danger = color("danger")

    // MARK: Mood skoru 1–5 — her zaman rakamla
    static let score1 = color("score-1")
    static let score2 = color("score-2")
    static let score3 = color("score-3")
    static let score4 = color("score-4")
    static let score5 = color("score-5")
    static let onScore1 = color("on-score-1")
    static let onScore2 = color("on-score-2")
    static let onScore3 = color("on-score-3")
    static let onScore4 = color("on-score-4")
    static let onScore5 = color("on-score-5")

    // MARK: Duygu aileleri
    static let emoNese = color("emo-nese")
    static let emoHuzur = color("emo-huzur")
    static let emoEnerji = color("emo-enerji")
    static let emoSevgi = color("emo-sevgi")
    static let emoKaygi = color("emo-kaygi")
    static let emoHuzun = color("emo-huzun")
    static let emoOfke = color("emo-ofke")
    static let emoYorgun = color("emo-yorgun")
    static let onEmoNese = color("on-emo-nese")
    static let onEmoHuzur = color("on-emo-huzur")
    static let onEmoEnerji = color("on-emo-enerji")
    static let onEmoSevgi = color("on-emo-sevgi")
    static let onEmoKaygi = color("on-emo-kaygi")
    static let onEmoHuzun = color("on-emo-huzun")
    static let onEmoOfke = color("on-emo-ofke")
    static let onEmoYorgun = color("on-emo-yorgun")

    /// 1–5 skorun dolgusu ve üstündeki rakam rengi. Aralık dışı değer 3'e düşer.
    static func score(_ value: Int) -> (fill: Color, on: Color) {
        switch value {
        case 1: return (score1, onScore1)
        case 2: return (score2, onScore2)
        case 4: return (score4, onScore4)
        case 5: return (score5, onScore5)
        default: return (score3, onScore3)
        }
    }

    // MARK: - Çözüm

    /// Token adından dinamik renk. Galeri ve testler için açık.
    static func color(_ name: String) -> Color {
        Color(uiColor(name))
    }

    static func uiColor(_ name: String) -> UIColor {
        UIColor { trait in
            let hex = ONE2Palette.hex(
                name,
                dark: trait.userInterfaceStyle == .dark,
                highContrast: trait.accessibilityContrast == .high
            )
            let c = ONE2Palette.rgba(hex)
            return UIColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
        }
    }
}
