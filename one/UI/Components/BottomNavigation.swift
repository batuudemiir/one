//
//  BottomNavigation.swift
//  one
//
//  Bottom tab navigation bar
//

import SwiftUI
import CloudKit

/// Prototipteki `.dock`. Cam kapsül, gösterge çubuğu ve büyük harf etiketler
/// bilinçli olarak yok — prototip düz bir yüzey: krem gradyanın üstünde
/// simge + küçük harf etiket, ortada tek kalıcı eylem.
struct BottomNavigation: View {
    @Binding var currentScreen: ScreenType
    @StateObject private var cloudKitManager = CloudKitManager.shared

    /// Bugün kayıt yapıldıysa o günün mood rengi. Doluysa ortadaki buton
    /// "+" olmaktan çıkıp mood rengine boyanmış bir onaya dönüşür
    /// (prototipteki `.fab.done`) — günün kapandığının tek işareti.
    var todayMoodColorHex: String? = nil

    /// Sekme tanımları `PrimaryTab`'dan gelir — tek kaynak.
    /// Ortadaki "+" bir sekme değil, kalıcı birincil eylem.
    private var leadingTabs: [PrimaryTab] { [.circle, .archive] }
    private var trailingTabs: [PrimaryTab] { [.echo, .profile] }

    var body: some View {
        HStack(spacing: 12) {
            tabGroup(leadingTabs)
            ritualButton
            tabGroup(trailingTabs)
        }
        .padding(.horizontal, ONETokens.spacingXL)
        .padding(.top, 12)
        // Prototipte dock ekranın DİBİNE oturuyor; 26pt onu havada
        // bırakıyordu. Güvenli alan zaten altta boşluk veriyor.
        .padding(.bottom, 6)
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: ONETokens.oneCream.opacity(0),    location: 0.0),
                    .init(color: ONETokens.oneCream.opacity(0.94), location: 0.32),
                    .init(color: ONETokens.oneCream.opacity(0.94), location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabGroup(_ tabs: [PrimaryTab]) -> some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.self) { tab in
                NavItem(
                    title: tab.title,
                    glyph: tab.glyph,
                    isSelected: isSelected(tab.screen),
                    badge: tab == .circle ? cloudKitManager.unseenFriendShareCount : 0
                ) {
                    withAnimation(ONEAnimation.tabSwitch) { currentScreen = tab.screen }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Bugünkü rengini bırak — her sekmeden tek dokunuş.
    private var ritualButton: some View {
        let moodColor = todayMoodColorHex.map { Color(hex: $0) }
        let isDone = moodColor != nil

        return Button {
            ONEHaptics.tabSwitch()
            withAnimation(ONEAnimation.cardSpring) { currentScreen = .today }
        } label: {
            Image(systemName: isDone ? "checkmark" : "plus")
                .font(.system(size: isDone ? 19 : 25, weight: isDone ? .semibold : .light))
                .foregroundColor(ONETokens.oneCream)
                .frame(width: 58, height: 58)
                .background(Circle().fill(moodColor ?? ONETokens.oneInk))
                .shadow(
                    color: (moodColor ?? ONETokens.oneInk).opacity(0.42),
                    radius: 11, x: 0, y: 8
                )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(ONEAnimation.cardSpring, value: isDone)
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

/// Prototipteki `.tab`: simge üstte (16pt), etiket altta (9.5pt), 4pt aralık.
/// Seçili sekme mürekkep + yarı kalın, diğerleri taş rengi. Seçimi gösteren
/// ayrı bir çubuk/nokta yok — renk ve ağırlık farkı yeterli.
struct NavItem: View {
    let title: String
    let glyph: TabGlyph
    let isSelected: Bool
    var badge: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    TabGlyphView(glyph: glyph, isSelected: isSelected)

                    if badge > 0 {
                        Circle()
                            .fill(ONETokens.oneBrand)
                            .frame(width: 7, height: 7)
                            .offset(x: 6, y: -3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(title)
                    .font(.system(size: 9.5, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? ONETokens.oneInk : ONETokens.oneStone)
            .animation(ONEAnimation.tabSwitch, value: isSelected)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(String(format: NSLocalizedString("nav.tabAccessibility", comment: ""), title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
