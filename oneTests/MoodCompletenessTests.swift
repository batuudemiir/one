//
//  MoodCompletenessTests.swift
//  oneTests
//
//  Property-Based Tests for Design System Tokens
//  Feature: design-system-tokens
//

import Testing
import SwiftUI
@testable import OneDailyBatuhan

/// **Validates: Requirements 3.10**
///
/// Property 1: Mood Completeness
/// For any mood in the ONEMood enum, that mood must provide all required properties:
/// color, hex, label, meaning, isDark, waveHeight, gradientStops, gradientStart, and gradientEnd.
struct MoodCompletenessTests {
    
    // MARK: - Property Test: All Moods Have Complete Properties
    
    @Test("All moods have non-empty color property")
    func testAllMoodsHaveColor() throws {
        for mood in ONEMood.allCases {
            // Color should be accessible and not crash
            let color = mood.color
            
            // Verify we can extract RGBA components (validates it's a real color)
            let uiColor = UIColor(color)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            
            let success = uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            #expect(success, "Mood \(mood.rawValue) should have a valid color")
        }
    }
    
    @Test("All moods have non-empty hex property")
    func testAllMoodsHaveHex() throws {
        for mood in ONEMood.allCases {
            let hex = mood.hex
            
            // Hex should not be empty
            #expect(!hex.isEmpty, "Mood \(mood.rawValue) should have a non-empty hex string")
            
            // Hex should be a valid format (starts with # and has 7 characters)
            #expect(hex.hasPrefix("#"), "Mood \(mood.rawValue) hex should start with #")
            #expect(hex.count == 7, "Mood \(mood.rawValue) hex should be 7 characters (#RRGGBB)")
            
            // Hex should contain only valid hex characters
            let hexChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef#")
            let hexString = hex.trimmingCharacters(in: hexChars)
            #expect(hexString.isEmpty, "Mood \(mood.rawValue) hex should contain only valid hex characters")
        }
    }
    
    @Test("All moods have non-empty label property")
    func testAllMoodsHaveLabel() throws {
        for mood in ONEMood.allCases {
            let label = mood.label
            
            // Label should not be empty
            #expect(!label.isEmpty, "Mood \(mood.rawValue) should have a non-empty label")
            
            // Label should have reasonable length (at least 2 characters)
            #expect(label.count >= 2, "Mood \(mood.rawValue) label should have at least 2 characters")
        }
    }
    
    @Test("All moods have non-empty meaning property")
    func testAllMoodsHaveMeaning() throws {
        for mood in ONEMood.allCases {
            let meaning = mood.meaning
            
            // Meaning should not be empty
            #expect(!meaning.isEmpty, "Mood \(mood.rawValue) should have a non-empty meaning")
            
            // Meaning should have reasonable length (at least 5 characters)
            #expect(meaning.count >= 5, "Mood \(mood.rawValue) meaning should have at least 5 characters")
        }
    }
    
    @Test("All moods have isDark property defined")
    func testAllMoodsHaveIsDark() throws {
        for mood in ONEMood.allCases {
            // isDark should be accessible (it's a Bool, so it's always defined)
            let isDark = mood.isDark
            
            // Verify it's a valid boolean (this will always pass, but documents the property)
            #expect(isDark == true || isDark == false, "Mood \(mood.rawValue) should have a valid isDark boolean")
        }
    }
    
    @Test("All moods have positive waveHeight property")
    func testAllMoodsHaveWaveHeight() throws {
        for mood in ONEMood.allCases {
            let waveHeight = mood.waveHeight
            
            // Wave height should be positive
            #expect(waveHeight > 0, "Mood \(mood.rawValue) should have a positive waveHeight, got \(waveHeight)")
            
            // Wave height should be reasonable (between 1 and 100)
            #expect(waveHeight >= 1 && waveHeight <= 100, 
                   "Mood \(mood.rawValue) waveHeight should be between 1 and 100, got \(waveHeight)")
        }
    }
    
    @Test("All moods have gradientStops with exactly 3 colors")
    func testAllMoodsHaveGradientStops() throws {
        for mood in ONEMood.allCases {
            let gradientStops = mood.gradientStops
            
            // Should have exactly 3 gradient stops
            #expect(gradientStops.count == 3, 
                   "Mood \(mood.rawValue) should have exactly 3 gradient stops, got \(gradientStops.count)")
            
            // All stops should be valid colors (verify we can convert to UIColor)
            for (index, color) in gradientStops.enumerated() {
                let uiColor = UIColor(color)
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                
                let success = uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                #expect(success, "Mood \(mood.rawValue) gradient stop \(index) should be a valid color")
            }
        }
    }
    
    @Test("All moods have gradientStart property")
    func testAllMoodsHaveGradientStart() throws {
        for mood in ONEMood.allCases {
            let gradientStart = mood.gradientStart
            
            // Gradient start should be a valid UnitPoint
            // UnitPoint coordinates should be between 0 and 1
            #expect(gradientStart.x >= 0 && gradientStart.x <= 1, 
                   "Mood \(mood.rawValue) gradientStart.x should be between 0 and 1")
            #expect(gradientStart.y >= 0 && gradientStart.y <= 1, 
                   "Mood \(mood.rawValue) gradientStart.y should be between 0 and 1")
        }
    }
    
    @Test("All moods have gradientEnd property")
    func testAllMoodsHaveGradientEnd() throws {
        for mood in ONEMood.allCases {
            let gradientEnd = mood.gradientEnd
            
            // Gradient end should be a valid UnitPoint
            // UnitPoint coordinates should be between 0 and 1
            #expect(gradientEnd.x >= 0 && gradientEnd.x <= 1, 
                   "Mood \(mood.rawValue) gradientEnd.x should be between 0 and 1")
            #expect(gradientEnd.y >= 0 && gradientEnd.y <= 1, 
                   "Mood \(mood.rawValue) gradientEnd.y should be between 0 and 1")
        }
    }
    
    // MARK: - Comprehensive Completeness Test
    
    @Test("All moods have all required properties defined")
    func testCompleteMoodProperties() throws {
        // This test verifies that all 8 moods have all required properties
        // by checking each mood individually
        
        for mood in ONEMood.allCases {
            // 1. Color property
            let color = mood.color
            let uiColor = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            #expect(uiColor.getRed(&r, green: &g, blue: &b, alpha: &a), 
                   "Mood \(mood.rawValue) should have a valid color")
            
            // 2. Hex property
            #expect(!mood.hex.isEmpty && mood.hex.count == 7, 
                   "Mood \(mood.rawValue) should have a valid hex string")
            
            // 3. Label property
            #expect(!mood.label.isEmpty && mood.label.count >= 2, 
                   "Mood \(mood.rawValue) should have a valid label")
            
            // 4. Meaning property
            #expect(!mood.meaning.isEmpty && mood.meaning.count >= 5, 
                   "Mood \(mood.rawValue) should have a valid meaning")
            
            // 5. isDark property (always defined for Bool)
            let _ = mood.isDark
            
            // 6. waveHeight property
            #expect(mood.waveHeight > 0 && mood.waveHeight <= 100, 
                   "Mood \(mood.rawValue) should have a valid waveHeight")
            
            // 7. gradientStops property
            #expect(mood.gradientStops.count == 3, 
                   "Mood \(mood.rawValue) should have exactly 3 gradient stops")
            
            // 8. gradientStart property
            let start = mood.gradientStart
            #expect(start.x >= 0 && start.x <= 1 && start.y >= 0 && start.y <= 1, 
                   "Mood \(mood.rawValue) should have a valid gradientStart")
            
            // 9. gradientEnd property
            let end = mood.gradientEnd
            #expect(end.x >= 0 && end.x <= 1 && end.y >= 0 && end.y <= 1, 
                   "Mood \(mood.rawValue) should have a valid gradientEnd")
        }
    }
    
    // MARK: - Specific Mood Validation Tests
    
    @Test("Verify all 8 moods are present")
    func testAllEightMoodsExist() throws {
        let allMoods = ONEMood.allCases
        
        // Should have exactly 8 moods
        #expect(allMoods.count == 8, "Should have exactly 8 moods, got \(allMoods.count)")
        
        // Verify each expected mood exists
        let expectedMoods: [ONEMood] = [.atesli, .enerjik, .isikli, .sakin, .derin, .gizemli, .bos, .temiz]
        for expectedMood in expectedMoods {
            #expect(allMoods.contains(expectedMood), "Should contain mood \(expectedMood.rawValue)")
        }
    }
    
    @Test("Each mood has unique properties")
    func testMoodsHaveUniqueProperties() throws {
        let allMoods = ONEMood.allCases
        
        // Collect all hex values
        let hexValues = allMoods.map { $0.hex }
        let uniqueHexValues = Set(hexValues)
        #expect(hexValues.count == uniqueHexValues.count, "All moods should have unique hex values")
        
        // Collect all labels
        let labels = allMoods.map { $0.label }
        let uniqueLabels = Set(labels)
        #expect(labels.count == uniqueLabels.count, "All moods should have unique labels")
        
        // Collect all meanings
        let meanings = allMoods.map { $0.meaning }
        let uniqueMeanings = Set(meanings)
        #expect(meanings.count == uniqueMeanings.count, "All moods should have unique meanings")
    }
}

