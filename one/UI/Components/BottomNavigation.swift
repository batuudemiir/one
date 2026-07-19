//
//  BottomNavigation.swift
//  one
//
//  Bottom tab navigation bar
//

import SwiftUI
import CloudKit

struct BottomNavigation: View {
    @Binding var currentScreen: ScreenType
    @Namespace private var tabIndicatorNamespace
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var profileImage: UIImage? = ProfileViewModel.loadProfilePhotoFromDisk()

    private var avatarColorHex: String {
        cloudKitManager.currentUser?["avatarColor"] as? String ?? "#5B8DEF"
    }

    /// Sekme tanımları `PrimaryTab`'dan gelir — tek kaynak.
    /// Ortadaki "+" bir sekme değil, kalıcı birincil eylem.
    private var leadingTabs: [PrimaryTab] { [.circle, .archive] }
    private var trailingTabs: [PrimaryTab] { [.echo, .profile] }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: ONETokens.oneCream.opacity(0),    location: 0.0),
                    .init(color: ONETokens.oneCream.opacity(0.6),  location: 0.28),
                    .init(color: ONETokens.oneCream.opacity(0.92), location: 0.55),
                    .init(color: ONETokens.oneCream,              location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)

            // Tek GlassEffectContainer: çubuk ve "+" birlikte morph olsun diye
            // ikisi de içeride. Ayrı konteynerlerde iOS 26 onları birbirinden
            // bağımsız cam yüzeyler olarak çizer ve geçiş efekti kaybolur.
            LiquidGlassContainer(spacing: 20) {
                HStack(spacing: 12) {
                    HStack(spacing: 0) {
                        ForEach(leadingTabs, id: \.self) { tab in
                            navItem(for: tab)
                            Spacer(minLength: 8)
                        }
                        ForEach(trailingTabs, id: \.self) { tab in
                            if tab != trailingTabs.first { Spacer(minLength: 8) }
                            navItem(for: tab)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .liquidGlass(.regular, in: Capsule())

                    ritualButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilePhotoDidChange)) { _ in
            profileImage = ProfileViewModel.loadProfilePhotoFromDisk()
        }
    }

    @ViewBuilder
    private func navItem(for tab: PrimaryTab) -> some View {
        if tab == .profile {
            ProfileNavItem(
                title: tab.title,
                isSelected: isSelected(tab.screen),
                namespace: tabIndicatorNamespace,
                profileImage: profileImage,
                avatarColorHex: avatarColorHex
            ) {
                withAnimation(ONEAnimation.tabSwitch) { currentScreen = tab.screen }
            }
        } else {
            NavItem(
                title: tab.title,
                icon: tab.icon,
                isSelected: isSelected(tab.screen),
                namespace: tabIndicatorNamespace,
                badge: tab == .circle ? cloudKitManager.unseenFriendShareCount : 0
            ) {
                withAnimation(ONEAnimation.tabSwitch) { currentScreen = tab.screen }
            }
        }
    }

    /// Bugünkü rengini bırak — her sekmeden tek dokunuş.
    private var ritualButton: some View {
        Button {
            ONEHaptics.tabSwitch()
            withAnimation(ONEAnimation.cardSpring) { currentScreen = .today }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(ONETokens.oneCream)
                .frame(width: 56, height: 56)
                .background(Circle().fill(ONETokens.oneInk))
                .shadow(color: ONETokens.oneInk.opacity(0.32), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(NSLocalizedString("nav.todayHint", comment: ""))
    }

    private func isSelected(_ screen: ScreenType) -> Bool {
        switch screen {
        case .today:
            return currentScreen == .today || currentScreen == .done
        default:
            return currentScreen == screen
        }
    }
}

struct ProfileNavItem: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let profileImage: UIImage?
    let avatarColorHex: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Color.clear.frame(width: 20, height: 4)
                        if isSelected {
                            Capsule()
                                .fill(ONETokens.oneInk)
                                .frame(width: 20, height: 4)
                                .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                        } else {
                            Circle()
                                .fill(ONETokens.oneCreamLow)
                                .frame(width: 5, height: 5)
                                .padding(.vertical, -0.5)
                        }
                    }
                }

                avatarView
                    .animation(ONEAnimation.tabSwitch, value: isSelected)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var avatarView: some View {
        if let img = profileImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 22, height: 22)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        isSelected ? ONETokens.oneInk : Color.clear,
                        lineWidth: 1.5
                    )
                )
        } else {
            Circle()
                .fill(Color(hex: avatarColorHex).opacity(0.85))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(
                        isSelected ? ONETokens.oneInk : Color.clear,
                        lineWidth: 1.5
                    )
                )
        }
    }
}

struct NavItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let namespace: Namespace.ID
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        // Invisible spacer to keep height consistent
                        Color.clear
                            .frame(width: 20, height: 4)

                        if isSelected {
                            Capsule()
                                .fill(ONETokens.oneInk)
                                .frame(width: 20, height: 4)
                                .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                        } else {
                            Circle()
                                .fill(ONETokens.oneCreamLow)
                                .frame(width: 5, height: 5)
                                .padding(.vertical, -0.5)
                        }
                    }

                    if badge > 0 {
                        Circle()
                            .fill(ONETokens.oneBrand)
                            .frame(width: 7, height: 7)
                            .offset(x: 4, y: -3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Prototipteki gibi: simge + etiket
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? ONETokens.oneInk : ONETokens.oneAsh)
                    .animation(ONEAnimation.tabSwitch, value: isSelected)

                Text(title.uppercased())
                    .monoSM(tracking: 2)
                    .foregroundColor(isSelected ? ONETokens.oneInk : ONETokens.oneAsh)
                    .animation(ONEAnimation.tabSwitch, value: isSelected)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(String(format: NSLocalizedString("nav.tabAccessibility", comment: ""), title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
