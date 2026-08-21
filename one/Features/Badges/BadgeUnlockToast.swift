//
//  BadgeUnlockToast.swift
//  one
//
//  Ephemeral banner shown when a badge unlocks
//

import SwiftUI

struct BadgeUnlockToast: ViewModifier {
    @ObservedObject private var manager = BadgeManager.shared
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let badge = manager.pendingToast, visible {
                    toast(badge: badge)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1000)
                }
            }
            .onChange(of: manager.pendingToast) { _, newValue in
                guard newValue != nil else { return }
                ONEHaptics.badgeUnlocked()
                withAnimation(.easeOut(duration: 0.3)) { visible = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                    withAnimation(.easeIn(duration: 0.3)) { visible = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        manager.pendingToast = nil
                    }
                }
            }
    }

    private func toast(badge: Badge) -> some View {
        HStack(spacing: V3Tokens.spacingMD) {
            Image(systemName: badge.iconSystemName)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(V3Tokens.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(V3Tokens.ink.opacity(0.08)))

            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("badges.unlocked", comment: ""))
                    .font(V3Typography.mono(9))
                    .tracking(1.2)
                    .foregroundColor(V3Tokens.mutedText)
                Text(badge.title)
                    .font(V3Typography.mono(13))
                    .foregroundColor(V3Tokens.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(V3Tokens.surface)
                .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(V3Tokens.ink.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, V3Tokens.spacingLG)
        .padding(.top, V3Tokens.spacingSM)
    }
}

extension View {
    func badgeUnlockToast() -> some View { modifier(BadgeUnlockToast()) }
}
