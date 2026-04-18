//
//  BottomNavigation.swift
//  one
//
//  Bottom tab navigation bar
//

import SwiftUI

struct BottomNavigation: View {
    @Binding var currentScreen: ScreenType
    @Namespace private var tabIndicatorNamespace
    @StateObject private var cloudKitManager = CloudKitManager.shared

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
        HStack(spacing: 0) {
            ForEach(tabs, id: \.title) { tab in
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
                if tab.title != tabs.last?.title {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .padding(.top, 16)
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: ONETokens.oneCream,              location: 0.0),
                    .init(color: ONETokens.oneCream.opacity(0.92), location: 0.45),
                    .init(color: ONETokens.oneCream.opacity(0.6),  location: 0.72),
                    .init(color: ONETokens.oneCream.opacity(0),    location: 1.0)
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
        )
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
