//
//  ColorUtils.swift
//  one
//
//  Color utilities for mood gradients
//

import SwiftUI

extension Color {
    /// Converts mood color to dark gradient stops for Wabi-Sabi aesthetic
    /// Returns a 3-stop gradient: [moodColor, intermediate blend, dark base]
    static func moodToGradient(hex: String) -> [Color] {
        // Use default color if hex is invalid
        let moodColor = hex.isEmpty ? ONETokens.oneBlue : Color(hex: hex)
        let darkBase = ONETokens.oneVoid
        
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
