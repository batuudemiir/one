//
//  Color+ONE.swift
//  one
//
//  Design System - Color Utilities
//  Provides hex color initialization utility
//

import SwiftUI

extension Color {
    /// Initialize a Color from a hex string
    /// Purpose: Enables color definition using standard hex notation for design tokens
    /// Supports formats: "#RGB", "#RRGGBB", "#RRGGBBAA"
    /// - Parameter hex: Hex string with or without "#" prefix
    /// - Returns: Color instance with parsed RGB/RGBA values
    /// - Note: Invalid formats return black (#000000) for graceful degradation
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension String {
    /// Network'ten gelen hex renk string'inin geçerliliğini kontrol eder.
    /// Geçerli formatlar: 3, 6 veya 8 hex karakter (# prefix opsiyonel).
    var isValidHexColor: Bool {
        let stripped = trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        return [3, 6, 8].contains(stripped.count) && stripped.allSatisfy(\.isHexDigit)
    }
}

extension Color {
    func darkened(by amount: Double) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(
            red: max(0, Double(r) * (1 - amount)),
            green: max(0, Double(g) * (1 - amount)),
            blue: max(0, Double(b) * (1 - amount))
        )
    }
}

extension UIColor {
    /// Initialize a UIColor from a hex string (for adaptive trait-based colors)
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
