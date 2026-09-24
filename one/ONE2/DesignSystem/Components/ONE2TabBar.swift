//
//  ONE2TabBar.swift
//  ONE 2.0
//
//  Yüzen cam alt gezinme + üstünde + hapı (components/TabBar.md, `.o-dock`).
//  - Sekme: ikon 24pt + 12pt etiket, hepsi `ink`; seçili sekme `ground` hap
//    içinde, ikon değişmez.
//  - Zemin cam, 1px `line` iç kenar, `shadow-float`; kenarlardan `space-4`.
//  - + hapı: 72×56 `primary`, tab bar'ın üstünden taşar.
//  Dock alt güvenli alanı yok sayar ve ekran altından `space-6` yukarıda
//  durur (kabuk `.ignoresSafeArea(edges: .bottom)` uygular).
//  Etiketler en fazla xxxLarge büyür; daha büyük metin boyutunda uzun
//  basış büyük içerik görüntüleyicisini açar.
//

import SwiftUI

struct ONE2TabBarItem<Tab: Hashable>: Identifiable {
    let tab: Tab
    let title: String
    let icon: ONE2Icon

    var id: Tab { tab }
}

struct ONE2Dock<Tab: Hashable>: View {
    let items: [ONE2TabBarItem<Tab>]
    @Binding var selection: Tab
    let addLabel: String
    let onAdd: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            tabBar
                .padding(.top, ONE2Size.dockTop)
            addButton
        }
        .padding(.horizontal, ONE2Space.gutter)
        .padding(.bottom, ONE2Space.s6)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                TabButton(item: item, isSelected: item.tab == selection) {
                    guard selection != item.tab else { return }
                    ONE2Haptics.selection()
                    selection = item.tab
                }
            }
        }
        .padding(ONE2Size.tabBarPadding)
        .one2Glass()
        .one2FloatShadow()
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var addButton: some View {
        Button(action: onAdd) {
            ONE2Icon.add.image(size: ONE2Size.iconLarge)
                .foregroundStyle(ONE2Color.onPrimary)
                .frame(width: ONE2Size.addButtonWidth, height: ONE2Size.addButtonHeight)
                .background(ONE2Color.primary, in: Capsule())
                .one2FloatShadow()
                .contentShape(Rectangle())
        }
        .buttonStyle(.one2Press)
        .accessibilityLabel(Text(addLabel))
    }
}

private struct TabButton<Tab: Hashable>: View {
    let item: ONE2TabBarItem<Tab>
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: ONE2Space.s1) {
                item.icon.image(size: ONE2Size.tabIcon)
                    .frame(height: ONE2Size.tabIcon)
                Text(item.title)
                    .one2Type(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(ONE2Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.top, ONE2Size.tabItemTop)
            .padding(.bottom, ONE2Space.s2)
            .background(isSelected ? ONE2Color.ground : .clear, in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.one2Press)
        .accessibilityLabel(Text(item.title))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityShowsLargeContentViewer {
            item.icon.image(size: ONE2Size.tabIcon)
            Text(item.title)
        }
    }
}

#if DEBUG
private struct DockSample: View {
    @State private var selection = 0
    private let items: [ONE2TabBarItem<Int>] = [
        .init(tab: 0, title: "Bugün", icon: .today),
        .init(tab: 1, title: "Sözler", icon: .quotes),
        .init(tab: 2, title: "Keşfet", icon: .explore),
        .init(tab: 3, title: "Yolculuk", icon: .journey),
        .init(tab: 4, title: "Eğilimler", icon: .insights),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            ONE2Color.ground.ignoresSafeArea()
            ONE2Dock(items: items, selection: $selection, addLabel: "Yeni girdi") {}
        }
    }
}

#Preview("Gece") { DockSample().preferredColorScheme(.dark) }
#Preview("Gün") { DockSample().preferredColorScheme(.light) }
#Preview("AX3") { DockSample().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#endif
