//
//  ColorUtils.swift
//  one
//
//  Color utilities for mood gradients
//

import SwiftUI
import UIKit

extension Color {
    /// Circular HSB hue difference between two hex colors, in degrees (0–180).
    /// Achromatic colors (saturation < 0.1) are treated as matching each other
    /// but not matching chromatic colors — hue is undefined for grays/blacks/whites.
    static func hsbHueDifference(hex1: String, hex2: String) -> Double {
        var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(hex: hex1).getHue(&h1, saturation: &s1, brightness: &b1, alpha: &a1)
        UIColor(hex: hex2).getHue(&h2, saturation: &s2, brightness: &b2, alpha: &a2)
        let achromatic1 = s1 < 0.1
        let achromatic2 = s2 < 0.1
        if achromatic1 && achromatic2 { return 0 }    // both gray → resonate
        if achromatic1 || achromatic2 { return 180 }  // one gray, one vivid → no resonance
        let deg1 = Double(h1) * 360
        let deg2 = Double(h2) * 360
        let diff = abs(deg1 - deg2)
        return min(diff, 360 - diff)
    }

    /// Converts mood color to dark gradient stops for Wabi-Sabi aesthetic
    /// Returns a 3-stop gradient: [moodColor, intermediate blend, dark base]
    static func moodToGradient(hex: String) -> [Color] {
        // Use default color if hex is invalid
        let moodColor = hex.isEmpty ? V3Tokens.info : Color(hex: hex)
        let darkBase = V3Tokens.darkGround
        
        // 3-stop gradient formula:
        // Stop 1 (0%): Pure mood color
        // Stop 2 (50%): Mood color at 40% opacity (creates blend effect)
        // Stop 3 (100%): Dark base #0D0D0E
        return [
            moodColor,                  // Stop 1: Pure mood color
            moodColor.opacity(0.4),     // Stop 2: Mood color at 40% opacity
            darkBase                    // Stop 3: Dark base
        ]
    }
}
