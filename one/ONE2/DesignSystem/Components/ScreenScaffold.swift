//
//  ScreenScaffold.swift
//  ONE 2.0
//
//  Sekme ekranı iskeleti (README Ekran anatomisi): üst çubuk slotları,
//  büyük küçük-harf başlık (`screenTitle`, sol hizalı; Bugün'de yok),
//  içerik, dock inseti, isteğe bağlı pull-to-refresh. İçerik yüzen dock'un
//  altından kayar; son öğe dock'un üstünde biter (`one2DockInset`).
//

import SwiftUI

// MARK: - Dock inseti

private struct DockInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Yüzen dock'un kapladığı alt yükseklik; kabuk ölçüp verir.
    var one2DockInset: CGFloat {
        get { self[DockInsetKey.self] }
        set { self[DockInsetKey.self] = newValue }
    }
}

// MARK: - Scaffold

struct ScreenScaffold<Leading: View, Center: View, Trailing: View, Content: View>: View {
    var title: String?
    var onRefresh: (() async -> Void)?
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let center: () -> Center
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content

    @Environment(\.one2DockInset) private var dockInset

    init(
        title: String? = nil,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder center: @escaping () -> Center,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.onRefresh = onRefresh
        self.leading = leading
        self.center = center
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ONE2Space.s5) {
                ONE2TopBar(leading: leading, center: center, trailing: trailing)
                if let title {
                    Text(title)
                        .one2Type(.screenTitle)
                        .foregroundStyle(ONE2Color.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                content()
            }
            .padding(.horizontal, ONE2Space.gutter)
            .padding(.top, ONE2Space.s2)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, dockInset + ONE2Space.s4, for: .scrollContent)
        .background(ONE2Color.ground.ignoresSafeArea())
        .modifier(RefreshModifier(action: onRefresh))
    }
}

private struct RefreshModifier: ViewModifier {
    let action: (() async -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.refreshable { await action() }
        } else {
            content
        }
    }
}

#if DEBUG
private struct ScaffoldSample: View {
    var body: some View {
        ScreenScaffold(title: "keşfet", onRefresh: {}) {
            EmptyView()
        } center: {
            EmptyView()
        } trailing: {
            ONE2RoundButton(icon: .search, accessibilityLabel: "Ara") {}
        } content: {
            VStack(spacing: ONE2Space.cardGap) {
                ForEach(0..<4, id: \.self) { _ in
                    Skeleton { ONE2Card { SkeletonLines(count: 3) } }
                }
            }
        }
    }
}

#Preview("Gece") { ScaffoldSample().preferredColorScheme(.dark) }
#Preview("Gün") { ScaffoldSample().preferredColorScheme(.light) }
#Preview("AX3") { ScaffoldSample().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#endif
