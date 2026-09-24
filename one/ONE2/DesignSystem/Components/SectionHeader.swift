//
//  SectionHeader.swift
//  ONE 2.0
//
//  Bölüm başlığı (README Ekran anatomisi): `title` + sağda "Tümünü gör ›"
//  ya da ikon butonu ("Pratiklerin" düzenle). Başlık `.isHeader`.
//

import SwiftUI

struct SectionHeader: View {
    enum Trailing {
        case none
        case seeAll(() -> Void)
        case icon(ONE2Icon, accessibilityLabel: String, action: () -> Void)
    }

    let title: String
    var trailing: Trailing = .none

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: ONE2Space.s3) {
            Text(title)
                .one2Type(.title)
                .foregroundStyle(ONE2Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            trailingView
        }
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .none:
            EmptyView()
        case .seeAll(let action):
            Button(action: action) {
                HStack(spacing: ONE2Space.s1) {
                    Text(one2String("one2.section.seeAll"))
                    ONE2Icon.chevronRight.image(size: ONE2Size.iconSmall).accessibilityHidden(true)
                }
                .one2Type(.headline)
                .foregroundStyle(ONE2Color.inkMuted)
                .frame(minHeight: ONE2Size.minTouch)
                .contentShape(Rectangle())
            }
            .buttonStyle(.one2Press)
        case .icon(let icon, let label, let action):
            ONE2RoundButton(icon: icon, accessibilityLabel: label, filled: false, action: action)
        }
    }
}

#if DEBUG
private struct SectionHeaderSamples: View {
    var body: some View {
        VStack(spacing: ONE2Space.s5) {
            SectionHeader(title: "Pratiklerin", trailing: .icon(.sliders, accessibilityLabel: "Düzenle", action: {}))
            SectionHeader(title: "Haftalık tema", trailing: .seeAll({}))
            SectionHeader(title: "Sabah")
        }
    }
}

#Preview("Gece") { SectionHeaderSamples().one2Preview(.gece) }
#Preview("Gün") { SectionHeaderSamples().one2Preview(.gun) }
#Preview("AX3") { SectionHeaderSamples().one2Preview(.ax3) }
#endif
