//
//  ProfileScreen.swift
//  ONE 2.0
//
//  Profil (Bugün'ün sağ üstünden). UX-3: iskelet + geliştirici ve
//  TestFlight için "Eski arayüze dön" (CLAUDE.md, iki kabuk tek build).
//  Gerçek profil UX-10'da.
//

import SwiftUI

struct ProfileScreen: View {
    let onBack: () -> Void

    var body: some View {
        RoutePlaceholderScreen(title: one2String("one2.route.profile"), onBack: onBack) {
            if ONE2Flag.canOverride {
                ShellSwitchRow()
            }
        }
    }
}

/// Yalnız geliştirme ve TestFlight: bir sonraki açılışta v3 kabuğuna dön.
private struct ShellSwitchRow: View {
    @State private var didSwitch = false

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s2) {
            Button {
                ONE2Flag.setOverride(false)
                didSwitch = true
            } label: {
                Text(one2String("one2.debug.useV3")).contentShape(Rectangle())
            }
            .buttonStyle(.one2(.secondary))
            if didSwitch {
                Text(one2String("one2.debug.restart"))
                    .one2Type(.bodySm)
                    .foregroundStyle(ONE2Color.inkMuted)
            }
        }
    }
}

#if DEBUG
#Preview("Gece") { ProfileScreen {}.preferredColorScheme(.dark) }
#Preview("Gün") { ProfileScreen {}.preferredColorScheme(.light) }
#Preview("AX3") { ProfileScreen {}.preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#endif
