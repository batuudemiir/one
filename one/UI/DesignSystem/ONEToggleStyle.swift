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
/// Components used: V3Tokens.info (active), V3Tokens.faintText (inactive), ONEAnimation.micro
struct ONEToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? V3Tokens.info : V3Tokens.faintText)
                    .frame(width: 44, height: 26)

                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .offset(x: configuration.isOn ? 9 : -9)
            }
            // Minimum 44×44pt hit target per Apple HIG
            .frame(minWidth: V3Tokens.minTouchTarget, minHeight: V3Tokens.minTouchTarget)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(ONEAnimation.micro) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

extension ToggleStyle where Self == ONEToggleStyle {
    /// ONE app toggle style
    static var one: ONEToggleStyle { ONEToggleStyle() }
}
