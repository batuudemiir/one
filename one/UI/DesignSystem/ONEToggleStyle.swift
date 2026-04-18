//
//  ONEToggleStyle.swift
//  one
//
//  Design System - Toggle and Navigation Components
//  Defines custom toggle style and navigation pip components
//

import SwiftUI

/// Custom toggle style using ONE design tokens
/// Purpose: Provides consistent toggle appearance across the app
/// Usage: Apply with .toggleStyle(.one) modifier
/// Components used: ONETokens.oneBlue (active), ONETokens.oneStone (inactive), ONEAnimation.micro
struct ONEToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? ONETokens.oneBlue : ONETokens.oneStone)
                    .frame(width: 44, height: 26)

                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .offset(x: configuration.isOn ? 9 : -9)
            }
            // Minimum 44×44pt hit target per Apple HIG
            .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(ONEAnimation.micro) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

/// Navigation pip indicator for bottom navigation
/// Purpose: Visual indicator for active navigation state
/// Usage: Bottom navigation bars, tab indicators, page indicators
/// Components used: ONETokens.oneInk (active), ONETokens.oneStone (inactive), ONEAnimation.micro
struct NavigationPip: View {
    let isActive: Bool
    
    var body: some View {
        Circle()
            .fill(isActive ? ONETokens.oneInk : ONETokens.oneStone)
            .frame(width: 6, height: 6)
            .animation(ONEAnimation.micro, value: isActive)
    }
}

extension ToggleStyle where Self == ONEToggleStyle {
    /// ONE app toggle style
    static var one: ONEToggleStyle { ONEToggleStyle() }
}
