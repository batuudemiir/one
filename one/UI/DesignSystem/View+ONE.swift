//
//  View+ONE.swift
//  one
//
//  Design System - View Modifiers
//  Provides convenient view modifiers for common styling patterns
//

import SwiftUI

extension View {
    
    // MARK: - Color Combination Modifiers
    
    /// Apply primary text color (oneInk)
    /// Purpose: Standard text color for maximum readability and hierarchy
    /// Usage: Headings, body text, primary content
    func primaryText() -> some View {
        self.foregroundColor(ONETokens.oneInk)
    }
    
    /// Apply secondary text color (oneAsh)
    /// Purpose: Secondary text with reduced emphasis
    /// Usage: Metadata, timestamps, supporting information
    func secondaryText() -> some View {
        self.foregroundColor(ONETokens.oneAsh)
    }
    
    /// Apply tertiary text color (oneCharcoal)
    /// Purpose: Tertiary text for minimal emphasis
    /// Usage: Placeholder text, disabled states, subtle labels
    func tertiaryText() -> some View {
        self.foregroundColor(ONETokens.oneCharcoal)
    }
    
    /// Apply muted text color (oneCreamLow)
    /// Purpose: Very subtle text that blends with background
    /// Usage: Watermarks, very subtle hints, background text
    func mutedText() -> some View {
        self.foregroundColor(ONETokens.oneCreamLow)
    }
    
    // MARK: - Background Modifiers
    
    /// Apply cream background
    /// Purpose: Standard light background for main content areas
    /// Usage: Screen backgrounds, main content areas
    func creamBackground() -> some View {
        self.background(ONETokens.oneCream)
    }
    
    /// Apply card background with standard radius
    /// Purpose: Elevated card appearance with rounded corners
    /// Usage: Cards, elevated panels, content containers
    func cardBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                .fill(ONETokens.oneCreamMid)
        )
    }
    
    // MARK: - Border Modifiers
    
    /// Apply standard card border
    /// Purpose: Subtle border for card separation and definition
    /// Usage: Card outlines, container borders, visual separation
    /// - Parameter color: Border color (default: oneStone)
    func cardBorder(color: Color = ONETokens.oneStone) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                .stroke(color, lineWidth: 1)
        )
    }
    
    // MARK: - Spacing Modifiers
    
    /// Apply standard horizontal padding (XL2 - 26pt)
    /// Purpose: Consistent horizontal screen margins
    /// Usage: Screen-level horizontal padding, main content margins
    func standardHorizontalPadding() -> some View {
        self.padding(.horizontal, ONETokens.spacingXL2)
    }
    
    /// Apply standard vertical padding (LG - 16pt)
    /// Purpose: Comfortable vertical spacing for content
    /// Usage: Section padding, content vertical spacing
    func standardVerticalPadding() -> some View {
        self.padding(.vertical, ONETokens.spacingLG)
    }
}
