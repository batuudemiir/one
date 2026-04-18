//
//  ONEAnimation.swift
//  one
//
//  Design System - Animation Tokens
//  Provides standardized durations and spring configurations
//

import SwiftUI

/// Animation tokens for the ONE app
/// Provides standardized durations and spring configurations
enum ONEAnimation {
    
    // MARK: - Duration Tokens
    
    /// Micro duration - 0.15s (very quick interactions)
    /// Intended effect: Instant feedback for micro-interactions, feels immediate
    /// Use for: Button presses, toggle switches, small state changes
    static let durationMicro: Double = 0.15
    
    /// Short duration - 0.25s (quick animations)
    /// Intended effect: Quick but noticeable transitions, snappy feel
    /// Use for: Menu transitions, small element animations, quick reveals
    static let durationShort: Double = 0.25
    
    /// Medium duration - 0.35s (standard animations)
    /// Intended effect: Standard comfortable animation speed, balanced feel
    /// Use for: Card movements, panel slides, standard transitions
    static let durationMedium: Double = 0.35
    
    /// Long duration - 0.55s (slow, deliberate animations)
    /// Intended effect: Deliberate, noticeable transitions with weight
    /// Use for: Screen transitions, important state changes, dramatic reveals
    static let durationLong: Double = 0.55
    
    /// Mood background duration - 1.4s (mood gradient transitions)
    /// Intended effect: Smooth, emotional mood color transitions that feel natural
    /// Use for: Mood gradient background changes, emotional state transitions
    static let durationMoodBg: Double = 1.4
    
    /// Pulse duration - 2.0s (pulsing animations)
    /// Intended effect: Gentle rhythmic pulsing that draws attention
    /// Use for: Loading indicators, attention-drawing elements, ambient animations
    static let durationPulse: Double = 2.0
    
    /// Breathe duration - 3.5s (breathing animations)
    /// Intended effect: Slow, calming breathing rhythm for ambient effects
    /// Use for: Background ambient animations, meditative effects, subtle life
    static let durationBreathe: Double = 3.5
    
    // MARK: - Animation Type Configurations
    
    /// Micro animation - subtle, quick interactions
    /// Response: 0.3, Damping: 0.7
    /// Intended effect: Snappy, responsive feel for immediate feedback
    /// Use for: Button presses, toggle switches, micro-interactions
    static let micro = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Card spring - smooth card movements
    /// Response: 0.45, Damping: 0.8
    /// Intended effect: Smooth, natural card movement with slight bounce
    /// Use for: Card animations, list item movements, content reveals
    static let cardSpring = Animation.spring(response: 0.45, dampingFraction: 0.8)
    
    /// Panel spring - panel and sheet transitions
    /// Response: 0.5, Damping: 0.85
    /// Intended effect: Smooth panel slides with controlled momentum
    /// Use for: Side panels, modal sheets, drawer animations
    static let panelSpring = Animation.spring(response: 0.5, dampingFraction: 0.85)
    
    /// Screen transition - full screen changes
    /// Response: 0.6, Damping: 0.9
    /// Intended effect: Smooth, weighty screen transitions with minimal bounce
    /// Use for: Navigation transitions, full screen changes, major view switches
    static let screenTransition = Animation.spring(response: 0.6, dampingFraction: 0.9)
    
    /// Mood transition - mood color changes
    /// Response: 0.7, Damping: 0.95
    /// Intended effect: Smooth, emotional color transitions without bounce
    /// Use for: Mood color changes, gradient transitions, emotional state shifts
    static let moodTransition = Animation.spring(response: 0.7, dampingFraction: 0.95)
    
    /// Tab switch - bottom navigation tab changes
    /// Response: 0.35, Damping: 0.75
    /// Intended effect: Snappy but fluid tab indicator movement with light bounce
    /// Use for: Bottom navigation indicator, tab selection changes
    static let tabSwitch = Animation.spring(response: 0.35, dampingFraction: 0.75)
    
    // MARK: - Stagger Animation
    
    /// Calculate stagger delay for list item animations
    /// Intended effect: Sequential reveal of list items with cascading timing
    /// Use for: List animations, sequential reveals, cascading effects
    /// - Parameters:
    ///   - index: Item index in the list
    ///   - baseDelay: Base delay between items (default: 0.08)
    /// - Returns: Delay in seconds for this item
    static func staggerDelay(index: Int, baseDelay: Double = 0.08) -> Double {
        return Double(index) * baseDelay
    }
    
    // MARK: - Button Press Style
    
    /// Scale for pressed button state
    /// Intended effect: Subtle scale-down that provides tactile feedback
    /// Use for: All button press interactions
    static let buttonPressScale: CGFloat = 0.96
    
    /// Animation for button press
    /// Intended effect: Quick, responsive press with slight bounce
    /// Use for: Button press down animation
    static let buttonPressAnimation = Animation.spring(response: 0.25, dampingFraction: 0.6)
    
    /// Animation for button release
    /// Intended effect: Smooth return to normal state with controlled bounce
    /// Use for: Button release animation
    static let buttonReleaseAnimation = Animation.spring(response: 0.35, dampingFraction: 0.7)
}

// MARK: - Animation View Modifiers

extension View {

    /// Apply button press animation effect
    /// - Parameter isPressed: Whether button is currently pressed
    func buttonPressEffect(isPressed: Bool) -> some View {
        self.scaleEffect(isPressed ? ONEAnimation.buttonPressScale : 1.0)
            .animation(
                isPressed ? ONEAnimation.buttonPressAnimation : ONEAnimation.buttonReleaseAnimation,
                value: isPressed
            )
    }

    /// Apply a standard page entrance animation (opacity + scale + vertical offset)
    /// Reduce Motion: offset/scale atlanır, sadece opacity geçişi yapılır.
    /// - Parameters:
    ///   - isVisible: Whether the element is visible (drive with @State appeared)
    ///   - delay: Delay before this element's entrance (default: 0)
    func pageEntrance(isVisible: Bool, delay: Double = 0) -> some View {
        modifier(PageEntranceModifier(isVisible: isVisible, delay: delay))
    }

    /// Apply a staggered list item entrance animation (opacity + vertical offset)
    /// Reduce Motion: offset atlanır, sadece opacity; stagger delay = 0.
    /// - Parameters:
    ///   - isVisible: Whether the item is visible
    ///   - index: Item index for stagger delay calculation
    ///   - baseDelay: Base delay before first item appears (default: 0)
    func listItemEntrance(isVisible: Bool, index: Int, baseDelay: Double = 0) -> some View {
        modifier(ListItemEntranceModifier(isVisible: isVisible, index: index, baseDelay: baseDelay))
    }

    /// Apply a standard directional slide transition
    /// Reduce Motion: sadece opacity transition kullanılır.
    /// - Parameter edge: The edge from which the element enters (default: .bottom)
    func slideTransition(edge: Edge = .bottom) -> some View {
        modifier(SlideTransitionModifier(edge: edge))
    }
}

// MARK: - Reduce-Motion-Aware Modifier Implementations

private struct PageEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isVisible: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.96))
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 8))
            .animation(
                reduceMotion
                    ? .easeOut(duration: ONEAnimation.durationMicro)
                    : ONEAnimation.panelSpring.delay(delay),
                value: isVisible
            )
    }
}

private struct ListItemEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isVisible: Bool
    let index: Int
    let baseDelay: Double

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 12))
            .animation(
                reduceMotion
                    ? .easeOut(duration: ONEAnimation.durationMicro)
                    : ONEAnimation.cardSpring.delay(baseDelay + ONEAnimation.staggerDelay(index: index)),
                value: isVisible
            )
    }
}

private struct SlideTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let edge: Edge

    func body(content: Content) -> some View {
        if reduceMotion {
            content.transition(.opacity)
        } else {
            content.transition(
                .asymmetric(
                    insertion: .move(edge: edge).combined(with: .opacity),
                    removal: .opacity
                )
            )
        }
    }
}

// MARK: - Breathing Animation Modifier

struct BreathingAnimation: ViewModifier {
    let delay: Double
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect((!reduceMotion && isAnimating) ? 1.05 : 1.0)
            .opacity(isAnimating ? 0.6 : 0.3)
            .animation(
                reduceMotion
                    ? .easeOut(duration: ONEAnimation.durationMicro)
                    : Animation.easeInOut(duration: ONEAnimation.durationBreathe)
                        .repeatForever(autoreverses: true)
                        .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    /// Apply breathing animation effect
    /// - Parameter delay: Delay before animation starts (default: 0)
    func breathingAnimation(delay: Double = 0) -> some View {
        self.modifier(BreathingAnimation(delay: delay))
    }
}
