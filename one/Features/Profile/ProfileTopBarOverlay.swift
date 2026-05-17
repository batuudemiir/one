//
//  ProfileTopBarOverlay.swift
//  one
//
//  Feature: ui-consistency-and-accessibility-sweep (Task 3.3)
//
//  Sticky top bar overlay extracted from `ProfileDashboardView`. Two circular
//  buttons sit above the hero — left: add friend, right: settings. Tint adapts
//  to whether a profile photo is present and to dark mode.
//

import SwiftUI
import UIKit

/// Overlay rendered at the top of the profile dashboard (`zIndex` over hero).
/// Exposes bindings so the parent view owns the sheet-presentation state for
/// add-friend and settings flows, keeping navigation entry points centralized.
struct ProfileTopBarOverlay: View {
    @ObservedObject var vm: ProfileViewModel
    @Environment(\.profilePalette) private var palette

    /// Presents the add-friend sheet when toggled `true` by the left button.
    @Binding var showAddFriend: Bool
    /// Presents the settings overlay when toggled `true` by the right button.
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            topBarButton(icon: "person.badge.plus",
                         a11y: NSLocalizedString("profile.addFriend.a11y", comment: "")) {
                showAddFriend = true
            }
            Spacer()
            topBarButton(icon: "gearshape.fill",
                         a11y: NSLocalizedString("profile.settings.a11y", comment: "")) {
                showSettings = true
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, safeAreaTop + 6)  // gerçek üst köşelere yapışık (önceki: +32)
    }

    /// Dynamic Island dahil gerçek safe area üst boşluğu.
    private var safeAreaTop: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top) ?? 54
    }

    private func topBarButton(icon: String, a11y: String, action: @escaping () -> Void) -> some View {
        let onPhoto = vm.profileImage != nil
        let tint: Color = {
            if onPhoto { return Color.black.opacity(0.40) }
            if vm.isDarkMode { return Color.black.opacity(0.55) }
            return Color.white.opacity(0.85)
        }()
        return Button(action: action) {
            Image(systemName: icon)
                .bodyLG()
                .foregroundColor(onPhoto ? .white : palette.primaryText)
                .frame(width: 38, height: 38)
                .liquidGlass(tint: tint, interactive: true, in: Circle())
                .shadow(color: .black.opacity(onPhoto ? 0.20 : 0.08), radius: 6, x: 0, y: 2)
        }
        .accessibilityLabel(a11y)
    }
}
