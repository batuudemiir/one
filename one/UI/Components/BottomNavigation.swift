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
    
    private struct Tab {
        let title: String
        let screen: ScreenType
    }
    
    private let tabs: [Tab] = [
        Tab(title: "yankı",  screen: .echo),
        Tab(title: "arşiv",  screen: .archive),
        Tab(title: "bugün",  screen: .today),
        Tab(title: "çevre",  screen: .circle),
        Tab(title: "profil", screen: .profile)
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.title) { tab in
                NavItem(
                    title: tab.title,
                    isSelected: isSelected(tab.screen),
                    namespace: tabIndicatorNamespace
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
        if screen == .today {
            return currentScreen == .today || currentScreen == .done
        }
        return currentScreen == screen
    }
}

struct NavItem: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Invisible spacer to keep height consistent
                    Color.clear
                        .frame(width: 20, height: 4)
                    
                    if isSelected {
                        Capsule()
                            .fill(Color.black)
                            .frame(width: 20, height: 4)
                            .matchedGeometryEffect(id: "tabIndicator", in: namespace)
                    } else {
                        Circle()
                            .fill(ONETokens.oneCreamLow)
                            .frame(width: 5, height: 5)
                            .padding(.vertical, -0.5)
                    }
                }
                
                Text(title.uppercased())
                    .monoSM(tracking: 2)
                    .foregroundColor(isSelected ? .black : ONETokens.oneAsh)
                    .animation(ONEAnimation.tabSwitch, value: isSelected)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
