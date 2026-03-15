//
//  MoodGradientConfigurationTests.swift
//  oneTests
//
//  Property-Based Tests for Design System Tokens
//  Feature: design-system-tokens
//

import Testing
import SwiftUI
@testable import OneDailyBatuhan

/// **Validates: Requirements 4.1, 4.2**
///
/// Property 2: Mood Gradient Configuration
/// For any mood in the ONEMood enum, the gradient stops must be a 3-element array containing:
/// the mood's color, the mood's color at 40% opacity, and the dark base color (oneVoid).
struct MoodGradientConfigurationTests {
    
    // MARK: - Property Test: Gradient Configuration Structure
    
    @Test("All moods have exactly 3 gradient stops")
    func testGradientStopsCount() throws {
        for mood in ONEMood.allCases {
            let gradientStops = mood.gradientStops
            
            #expect(gradientStops.count == 3,
                   "Mood \(mood.rawValue) should have exactly 3 gradient stops, got \(gradientStops.count)")
        }
    }
    
    // MARK: - Property Test: First Stop is Mood Color
    
    @Test("First gradient stop is the mood's color")
    func testFirstStopIsMoodColor() throws {
        for mood in ONEMood.allCases {
            let gradientStops = mood.gradientStops
            let firstStop = gradientStops[0]
            let moodColor = mood.color
            
            // Compare RGB components
            let firstStopUI = UIColor(firstStop)
            let moodColorUI = UIColor(moodColor)
            
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            
            firstStopUI.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            moodColorUI.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            
            // Allow small floating-point tolerance
            let tolerance: CGFloat = 0.01
            
            #expect(abs(r1 - r2) < tolerance,
                   "Mood \(mood.rawValue) first stop red component should match mood color")
            #expect(abs(g1 - g2) < tolerance,
                   "Mood \(mood.rawValue) first stop green component should match mood color")
            #expect(abs(b1 - b2) < tolerance,
                   "Mood \(mood.rawValue) first stop blue component should match mood color")
            #expect(abs(a1 - a2) < tolerance,
                   "Mood \(mood.rawValue) first stop alpha component should match mood color")
        }
    }
    
    // MARK: - Property Test: Second Stop is Mood Color at 40% Opacity
    
    @Test("Second gradient stop is the mood's color at 40% opacity")
    func testSecondStopIsMoodColorAt40Percent() throws {
        for mood in ONEMood.allCases {
            let gradientStops = mood.gradientStops
            let secondStop = gradientStops[1]
            let expectedColor = mood.color.opacity(0.4)
            
            // Compare RGB components
            let secondStopUI = UIColor(secondStop)
            let expectedColorUI = UIColor(expectedColor)
            
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            
            secondStopUI.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            expectedColorUI.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            
            // Allow small floating-point tolerance
            let tolerance: CGFloat = 0.01
            
            #expect(abs(r1 - r2) < tolerance,
                   "Mood \(mood.rawValue) second stop red component should match mood color at 40% opacity")
            #expect(abs(g1 - g2) < tolerance,
                   "Mood \(mood.rawValue) second stop green component should match mood color at 40% opacity")
            #expect(abs(b1 - b2) < tolerance,
                   "Mood \(mood.rawValue) second stop blue component should match mood color at 40% opacity")
            #expect(abs(a1 - a2) < tolerance,
                   "Mood \(mood.rawValue) second stop alpha component should match mood color at 40% opacity")
        }
    }
    
    // MARK: - Property Test: Third Stop is Dark Base (oneVoid)
    
    @Test("Third gradient stop is the dark base color (oneVoid)")
    func testThirdStopIsDarkBase() throws {
        let darkBase = ONETokens.oneVoid
        
        for mood in ONEMood.allCases {
            let gradientStops = mood.gradientStops
            let thirdStop = gradientStops[2]
            
            // Compare RGB components
            let thirdStopUI = UIColor(thirdStop)
            let darkBaseUI = UIColor(darkBase)
            
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            
            thirdStopUI.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            darkBaseUI.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            
            // Allow small floating-point tolerance
            let tolerance: CGFloat = 0.01
            
            #expect(abs(r1 - r2) < tolerance,
                   "Mood \(mood.rawValue) third stop red component should match oneVoid")
            #expect(abs(g1 - g2) < tolerance,
                   "Mood \(mood.rawValue) third stop green component should match oneVoid")
            #expect(abs(b1 - b2) < tolerance,
                   "Mood \(mood.rawValue) third stop blue component should match oneVoid")
            #expect(abs(a1 - a2) < tolerance,
                   "Mood \(mood.rawValue) third stop alpha component should match oneVoid")
        }
    }
    
    // MARK: - Comprehensive Gradient Configuration Test
    
    @Test("All moods have correct gradient configuration")
    func testCompleteGradientConfiguration() throws {
        let darkBase = ONETokens.oneVoid
        let tolerance: CGFloat = 0.01
        
        for mood in ONEMood.allCases {
            let gradientStops = mood.gradientStops
            
            // 1. Verify count
            #expect(gradientStops.count == 3,
                   "Mood \(mood.rawValue) should have exactly 3 gradient stops")
            
            // 2. Verify first stop is mood color
            let firstStop = UIColor(gradientStops[0])
            let moodColor = UIColor(mood.color)
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            
            firstStop.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            moodColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            
            #expect(abs(r1 - r2) < tolerance && abs(g1 - g2) < tolerance && abs(b1 - b2) < tolerance,
                   "Mood \(mood.rawValue) first stop should match mood color")
            
            // 3. Verify second stop is mood color at 40% opacity
            let secondStop = UIColor(gradientStops[1])
            let expectedSecond = UIColor(mood.color.opacity(0.4))
            var r3: CGFloat = 0, g3: CGFloat = 0, b3: CGFloat = 0, a3: CGFloat = 0
            var r4: CGFloat = 0, g4: CGFloat = 0, b4: CGFloat = 0, a4: CGFloat = 0
            
            secondStop.getRed(&r3, green: &g3, blue: &b3, alpha: &a3)
            expectedSecond.getRed(&r4, green: &g4, blue: &b4, alpha: &a4)
            
            #expect(abs(r3 - r4) < tolerance && abs(g3 - g4) < tolerance && abs(b3 - b4) < tolerance,
                   "Mood \(mood.rawValue) second stop should match mood color at 40% opacity")
            
            // 4. Verify third stop is dark base
            let thirdStop = UIColor(gradientStops[2])
            let darkBaseUI = UIColor(darkBase)
            var r5: CGFloat = 0, g5: CGFloat = 0, b5: CGFloat = 0, a5: CGFloat = 0
            var r6: CGFloat = 0, g6: CGFloat = 0, b6: CGFloat = 0, a6: CGFloat = 0
            
            thirdStop.getRed(&r5, green: &g5, blue: &b5, alpha: &a5)
            darkBaseUI.getRed(&r6, green: &g6, blue: &b6, alpha: &a6)
            
            #expect(abs(r5 - r6) < tolerance && abs(g5 - g6) < tolerance && abs(b5 - b6) < tolerance,
                   "Mood \(mood.rawValue) third stop should match oneVoid")
        }
    }
    
    // MARK: - Gradient Order Validation
    
    @Test("Gradient stops are in correct order")
    func testGradientStopsOrder() throws {
        for mood in ONEMood.allCases {
            let gradientStops = mood.gradientStops
            
            // Verify we have 3 stops
            guard gradientStops.count == 3 else {
                Issue.record("Mood \(mood.rawValue) should have 3 gradient stops")
                continue
            }
            
            // Extract colors
            let stop1 = UIColor(gradientStops[0])
            let stop2 = UIColor(gradientStops[1])
            let stop3 = UIColor(gradientStops[2])
            
            // Get RGB components
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            var r3: CGFloat = 0, g3: CGFloat = 0, b3: CGFloat = 0, a3: CGFloat = 0
            
            stop1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            stop2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            stop3.getRed(&r3, green: &g3, blue: &b3, alpha: &a3)
            
            // Verify stop 1 has full opacity (or close to it)
            #expect(a1 > 0.9, "Mood \(mood.rawValue) first stop should have full opacity")
            
            // Verify stop 2 has reduced opacity (around 0.4)
            #expect(a2 > 0.3 && a2 < 0.5, 
                   "Mood \(mood.rawValue) second stop should have ~40% opacity, got \(a2)")
            
            // Verify stop 3 is the dark base (oneVoid = #0D0D0E)
            // oneVoid is very dark, so RGB values should be close to 0
            #expect(r3 < 0.1 && g3 < 0.1 && b3 < 0.1,
                   "Mood \(mood.rawValue) third stop should be dark (oneVoid)")
        }
    }
    
    // MARK: - Gradient Start and End Points
    
    @Test("All moods have valid gradient start and end points")
    func testGradientStartEndPoints() throws {
        for mood in ONEMood.allCases {
            let start = mood.gradientStart
            let end = mood.gradientEnd
            
            // Verify start point is valid
            #expect(start.x >= 0 && start.x <= 1,
                   "Mood \(mood.rawValue) gradientStart.x should be between 0 and 1")
            #expect(start.y >= 0 && start.y <= 1,
                   "Mood \(mood.rawValue) gradientStart.y should be between 0 and 1")
            
            // Verify end point is valid
            #expect(end.x >= 0 && end.x <= 1,
                   "Mood \(mood.rawValue) gradientEnd.x should be between 0 and 1")
            #expect(end.y >= 0 && end.y <= 1,
                   "Mood \(mood.rawValue) gradientEnd.y should be between 0 and 1")
            
            // Verify start and end are different (otherwise no gradient)
            #expect(start != end,
                   "Mood \(mood.rawValue) gradientStart and gradientEnd should be different")
        }
    }
}
