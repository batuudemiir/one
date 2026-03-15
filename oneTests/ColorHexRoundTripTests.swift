//
//  ColorHexRoundTripTests.swift
//  oneTests
//
//  Property-Based Tests for Design System Tokens
//  Feature: design-system-tokens
//

import Testing
import SwiftUI
@testable import OneDailyBatuhan

/// **Validates: Requirements 12.2, 12.3, 12.4, 12.5**
///
/// Property 3: Hex Color Round-Trip
/// For any valid hex string (3, 6, or 8 characters, with or without "#" prefix),
/// initializing a Color with that hex string and then extracting its RGB components
/// should produce values that match the original hex values (within floating-point tolerance).
struct ColorHexRoundTripTests {
    
    // MARK: - Helper Functions
    
    /// Extract RGB components from a Color
    /// Returns (red, green, blue, alpha) as values from 0-255
    private func extractRGBA(from color: Color) -> (r: Int, g: Int, b: Int, a: Int)? {
        // Convert Color to UIColor to extract components
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        
        return (
            r: Int(round(red * 255)),
            g: Int(round(green * 255)),
            b: Int(round(blue * 255)),
            a: Int(round(alpha * 255))
        )
    }
    
    /// Parse hex string to expected RGBA values
    private func parseHexToRGBA(_ hex: String) -> (r: Int, g: Int, b: Int, a: Int) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        return (r: Int(r), g: Int(g), b: Int(b), a: Int(a))
    }
    
    /// Verify color round-trip with tolerance
    private func verifyRoundTrip(_ hexString: String, tolerance: Int = 1) throws {
        let color = Color(hex: hexString)
        let expected = parseHexToRGBA(hexString)
        
        guard let actual = extractRGBA(from: color) else {
            Issue.record("Failed to extract RGBA from color created with hex: \(hexString)")
            return
        }
        
        // Check each component with tolerance
        #expect(abs(actual.r - expected.r) <= tolerance,
                "Red mismatch for \(hexString): expected \(expected.r), got \(actual.r)")
        #expect(abs(actual.g - expected.g) <= tolerance,
                "Green mismatch for \(hexString): expected \(expected.g), got \(actual.g)")
        #expect(abs(actual.b - expected.b) <= tolerance,
                "Blue mismatch for \(hexString): expected \(expected.b), got \(actual.b)")
        #expect(abs(actual.a - expected.a) <= tolerance,
                "Alpha mismatch for \(hexString): expected \(expected.a), got \(actual.a)")
    }
    
    // MARK: - Property Tests: 3-Character Hex (RGB)
    
    @Test("3-char hex with # prefix - pure colors")
    func testThreeCharHexWithPrefix() throws {
        let testCases = [
            "#F00", // Red
            "#0F0", // Green
            "#00F", // Blue
            "#FFF", // White
            "#000", // Black
            "#888", // Gray
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("3-char hex without # prefix")
    func testThreeCharHexWithoutPrefix() throws {
        let testCases = [
            "F00", // Red
            "0F0", // Green
            "00F", // Blue
            "ABC", // Light gray-blue
            "123", // Dark gray
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("3-char hex - various combinations")
    func testThreeCharHexVariousCombinations() throws {
        // Test a range of 3-char hex values
        let testCases = [
            "#F0F", "#0FF", "#FF0",
            "#F88", "#8F8", "#88F",
            "#F44", "#4F4", "#44F",
            "#FAB", "#BCD", "#DEF",
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    // MARK: - Property Tests: 6-Character Hex (RRGGBB)
    
    @Test("6-char hex with # prefix - pure colors")
    func testSixCharHexWithPrefix() throws {
        let testCases = [
            "#FF0000", // Red
            "#00FF00", // Green
            "#0000FF", // Blue
            "#FFFFFF", // White
            "#000000", // Black
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("6-char hex without # prefix")
    func testSixCharHexWithoutPrefix() throws {
        let testCases = [
            "FF0000", // Red
            "00FF00", // Green
            "0000FF", // Blue
            "ABCDEF", // Light blue
            "123456", // Dark blue-gray
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("6-char hex - mood colors from design system")
    func testSixCharHexMoodColors() throws {
        // Test actual mood colors from the design system
        let testCases = [
            "#E84040", // atesli
            "#FF8C42", // enerjik
            "#F5C842", // isikli
            "#4CAF82", // sakin
            "#5B8DEF", // derin
            "#9B7FD4", // gizemli
            "#2C2C2C", // bos
            "#E8E6E0", // temiz
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("6-char hex - neutral colors from design system")
    func testSixCharHexNeutralColors() throws {
        let testCases = [
            "#F7F6F3", // oneCream
            "#EEECEA", // oneCreamMid
            "#E8E6E0", // oneCreamLow
            "#D8D6D0", // oneStone
            "#BFBDB5", // oneAsh
            "#999591", // oneCharcoal
            "#111112", // oneInk
            "#0D0D0E", // oneVoid
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("6-char hex - various combinations")
    func testSixCharHexVariousCombinations() throws {
        let testCases = [
            "#FF00FF", "#00FFFF", "#FFFF00",
            "#FF8800", "#88FF00", "#0088FF",
            "#FF4444", "#44FF44", "#4444FF",
            "#AABBCC", "#CCDDEE", "#EEFFAA",
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    // MARK: - Property Tests: 8-Character Hex (AARRGGBB)
    
    @Test("8-char hex with # prefix - full opacity")
    func testEightCharHexWithPrefixFullOpacity() throws {
        let testCases = [
            "#FFFF0000", // Red, full opacity
            "#FF00FF00", // Green, full opacity
            "#FF0000FF", // Blue, full opacity
            "#FFFFFFFF", // White, full opacity
            "#FF000000", // Black, full opacity
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("8-char hex without # prefix - full opacity")
    func testEightCharHexWithoutPrefixFullOpacity() throws {
        let testCases = [
            "FFFF0000", // Red, full opacity
            "FF00FF00", // Green, full opacity
            "FF0000FF", // Blue, full opacity
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("8-char hex - various alpha values")
    func testEightCharHexVariousAlpha() throws {
        let testCases = [
            "#80FF0000", // Red, 50% opacity
            "#40FF0000", // Red, 25% opacity
            "#C0FF0000", // Red, 75% opacity
            "#00FF0000", // Red, 0% opacity
            "#80FFFFFF", // White, 50% opacity
            "#4000FF00", // Green, 25% opacity
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("8-char hex - complex combinations")
    func testEightCharHexComplexCombinations() throws {
        let testCases = [
            "#FFAABBCC", "#80CCDDEE", "#40EEFFAA",
            "#C0FF8800", "#8088FF00", "#400088FF",
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Edge case - lowercase hex")
    func testLowercaseHex() throws {
        let testCases = [
            "#ff0000", "#00ff00", "#0000ff",
            "#abcdef", "#fedcba",
            "ff0000", "abcdef",
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("Edge case - mixed case hex")
    func testMixedCaseHex() throws {
        let testCases = [
            "#Ff0000", "#00Ff00", "#0000Ff",
            "#AbCdEf", "#FeDcBa",
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
    
    @Test("Edge case - boundary values")
    func testBoundaryValues() throws {
        let testCases = [
            "#000000", // All zeros
            "#FFFFFF", // All max
            "#FF0000", // Max red
            "#00FF00", // Max green
            "#0000FF", // Max blue
            "#000001", // Min non-zero
            "#FFFFFE", // Max minus one
        ]
        
        for hex in testCases {
            try verifyRoundTrip(hex)
        }
    }
}
