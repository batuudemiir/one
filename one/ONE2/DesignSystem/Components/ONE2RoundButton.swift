//
//  ONE2RoundButton.swift
//  ONE 2.0
//
//  Yuvarlak ikon butonu (`.o-round`): 48pt, raised, SF Symbol. Etiket
//  zorunlu (VoiceOver). `filled: false` bölüm başlığındaki düzenle ikonu
//  gibi zeminsiz kullanım için.
//

import SwiftUI

struct ONE2RoundButton: View {
    let icon: ONE2Icon
    let accessibilityLabel: String
    var filled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            icon.image()
                .foregroundStyle(ONE2Color.ink)
                .frame(width: ONE2Size.control, height: ONE2Size.control)
                .background(filled ? ONE2Color.raised : .clear, in: Circle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.one2Press)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

#if DEBUG
private struct RoundSamples: View {
    var body: some View {
        HStack(spacing: ONE2Space.s3) {
            ONE2RoundButton(icon: .brush, accessibilityLabel: "Arka plan") {}
            ONE2RoundButton(icon: .play, accessibilityLabel: "Oynat") {}
            ONE2RoundButton(icon: .search, accessibilityLabel: "Ara") {}
            ONE2RoundButton(icon: .sliders, accessibilityLabel: "Düzenle", filled: false) {}
        }
    }
}

#Preview("Gece") { RoundSamples().one2Preview(.gece) }
#Preview("Gün") { RoundSamples().one2Preview(.gun) }
#Preview("AX3") { RoundSamples().one2Preview(.ax3) }
#endif
