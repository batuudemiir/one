//
//  SettingsComponents.swift
//  One - Günlük Mood
//
//  Design System - Settings Components
//  Reusable UI components for building settings screens with a minimum interaction target.
//

import SwiftUI

/// Standardized Row for Settings
struct ONESettingsRow: View {
    let icon: String
    let title: String
    let value: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(ONETokens.oneInk)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(ONETokens.oneInk)
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(.custom("GeistMono-Regular", size: 13))
                        .foregroundColor(ONETokens.oneAsh)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ONETokens.oneStone)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(minHeight: 44) // Accessibility: Minimum hit target
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(ONETokens.oneCream),
                alignment: .bottom
            )
        }
    }
}

/// Standardized Toggle Component for Settings
struct ONESettingsToggle: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ONETokens.oneInk)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(ONETokens.oneInk)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(ONETokens.oneInk)
                .labelsHidden()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .frame(minHeight: 44) // Accessibility: Minimum hit target
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(ONETokens.oneCream),
            alignment: .bottom
        )
    }
}
