#!/usr/bin/swift
//
//  verify_hex_tests.swift
//  Quick verification script for hex color round-trip logic
//

import Foundation
import SwiftUI
import UIKit

extension Color {
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

func parseHexToRGBA(_ hex: String) -> (r: Int, g: Int, b: Int, a: Int) {
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

func extractRGBA(from color: Color) -> (r: Int, g: Int, b: Int, a: Int)? {
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

// Test cases
let testCases = [
    "#FF0000", // Red
    "#00FF00", // Green
    "#0000FF", // Blue
    "#F00",    // Red (3-char)
    "FF0000",  // Red (no #)
    "#E84040", // atesli mood color
    "#FFFF0000", // Red with alpha
]

print("Testing hex color round-trip...")
print("================================")

var passedTests = 0
var failedTests = 0

for hexString in testCases {
    let color = Color(hex: hexString)
    let expected = parseHexToRGBA(hexString)
    
    if let actual = extractRGBA(from: color) {
        let tolerance = 1
        let rMatch = abs(actual.r - expected.r) <= tolerance
        let gMatch = abs(actual.g - expected.g) <= tolerance
        let bMatch = abs(actual.b - expected.b) <= tolerance
        let aMatch = abs(actual.a - expected.a) <= tolerance
        
        if rMatch && gMatch && bMatch && aMatch {
            print("✓ PASS: \(hexString)")
            print("  Expected: R=\(expected.r) G=\(expected.g) B=\(expected.b) A=\(expected.a)")
            print("  Actual:   R=\(actual.r) G=\(actual.g) B=\(actual.b) A=\(actual.a)")
            passedTests += 1
        } else {
            print("✗ FAIL: \(hexString)")
            print("  Expected: R=\(expected.r) G=\(expected.g) B=\(expected.b) A=\(expected.a)")
            print("  Actual:   R=\(actual.r) G=\(actual.g) B=\(actual.b) A=\(actual.a)")
            failedTests += 1
        }
    } else {
        print("✗ FAIL: \(hexString) - Could not extract RGBA")
        failedTests += 1
    }
    print()
}

print("================================")
print("Results: \(passedTests) passed, \(failedTests) failed")
print("================================")

if failedTests == 0 {
    print("✓ All tests passed!")
    exit(0)
} else {
    print("✗ Some tests failed")
    exit(1)
}
