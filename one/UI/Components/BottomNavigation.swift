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

    private struct Tab {
        let title: String
        let icon: String
        let screen: ScreenType
    }

    private var tabs: [Tab] {[
        Tab(title: NSLocalizedString("nav.discover", comment: ""), icon: "sparkles",   screen: .discover),
        Tab(title: NSLocalizedString("nav.archive",  comment: ""), icon: "calendar",   screen: .archive),
        Tab(title: NSLocalizedString("nav.today",    comment: ""), icon: "music.note", screen: .today),
        Tab(title: NSLocalizedString("nav.circle",   comment: ""), icon: "person.2",   screen: .circle),
        Tab(title: NSLocalizedString("nav.profile",  comment: ""), icon: "person",     screen: .profile)
    ]}

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

            LiquidGlassContainer(spacing: 24) {
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.title) { tab in
                        if tab.screen == .profile {
                            ProfileNavItem(
                                title: tab.title,
                                isSelected: isSelected(tab.screen),
                                namespace: tabIndicatorNamespace,
                                profileImage: profileImage,
                                avatarColorHex: avatarColorHex
                            ) {
                                withAnimation(ONEAnimation.tabSwitch) {
                                    currentScreen = tab.screen
                                }
                            }
                        } else {
                            NavItem(
                                title: tab.title,
                                icon: tab.icon,
                                isSelected: isSelected(tab.screen),
                                namespace: tabIndicatorNamespace,
                                badge: tab.screen == .circle ? cloudKitManager.unseenFriendShareCount : 0
                            ) {
                                withAnimation(ONEAnimation.tabSwitch) {
                                    currentScreen = tab.screen
                                }
                            }
                        }
                        if tab.title != tabs.last?.title {
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .liquidGlass(.regular, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilePhotoDidChange)) { _ in
            profileImage = ProfileViewModel.loadProfilePhotoFromDisk()
        }
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
