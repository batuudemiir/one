//
//  ONE2TopBar.swift
//  ONE 2.0
//
//  Her ekranın üst satırı (components/TopBar.md, `.o-topbar`): sol / orta /
//  sağ slot. Orta slot kalan genişliği alır ve ortalar (grid auto 1fr auto).
//  Başlık ayrı satırda, `ScreenScaffold` çizer.
//

import SwiftUI

struct ONE2TopBar<Leading: View, Center: View, Trailing: View>: View {
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let center: () -> Center
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: ONE2Space.s3) {
            leading()
                .layoutPriority(1)
            // Orta slot boşken (EmptyView) de sağ slot sağda kalsın diye
            // esnek boşluklarla sarılır; `frame(maxWidth:)` EmptyView'da yer açmaz.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                center()
                Spacer(minLength: 0)
            }
            HStack(spacing: ONE2Space.s3) { trailing() }
                .layoutPriority(1)
        }
        .frame(minHeight: ONE2Size.control)
    }
}

#if DEBUG
private struct TopBarSamples: View {
    var body: some View {
        VStack(spacing: ONE2Space.s8) {
            ONE2TopBar {
                ONE2Pill(action: {}) {
                    HStack(spacing: ONE2Space.s2) {
                        ONE2Icon.streak.image(size: ONE2Size.iconSmall)
                        Text(verbatim: "12").one2Type(.time).foregroundStyle(ONE2Color.brand)
                    }
                }
            } center: {
                Text(verbatim: "iyi akşamlar").one2Type(.greeting).foregroundStyle(ONE2Color.ink)
            } trailing: {
                ONE2RoundButton(icon: .profile, accessibilityLabel: "Profil") {}
            }
            ONE2TopBar {
                ONE2Pill("Sana özel", showsChevron: true) {}
            } center: {
                EmptyView()
            } trailing: {
                ONE2RoundButton(icon: .brush, accessibilityLabel: "Arka plan") {}
                ONE2RoundButton(icon: .play, accessibilityLabel: "Oynat") {}
                ONE2RoundButton(icon: .search, accessibilityLabel: "Ara") {}
            }
        }
    }
}

#Preview("Gece") { TopBarSamples().one2Preview(.gece) }
#Preview("Gün") { TopBarSamples().one2Preview(.gun) }
#Preview("AX3") { TopBarSamples().one2Preview(.ax3) }
#endif
