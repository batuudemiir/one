//
//  ONE2Pill.swift
//  ONE 2.0
//
//  Üst çubuk hapı (components/TopBar.md, `.o-pill`): raised zemin, 48pt,
//  pill; ikon + metin, isteğe bağlı açılır ok ("Sana özel ⌄", "Günler ⌄").
//  Seri hapı gibi özel içerik için `label:` başlatıcısı.
//

import SwiftUI

struct ONE2Pill<Content: View>: View {
    private let action: () -> Void
    private let label: Content
    @Environment(\.isEnabled) private var isEnabled

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Content) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .one2Type(.headline)
                .foregroundStyle(isEnabled ? ONE2Color.ink : ONE2Color.inkFaint)
                .padding(.horizontal, ONE2Size.pillPadding)
                .frame(minHeight: ONE2Size.control)
                .background(ONE2Color.raised, in: Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(.one2Press)
    }
}

extension ONE2Pill where Content == ONE2PillLabel {
    /// Metinli hap; `showsChevron` açılır menü hapları için.
    init(_ title: String, icon: ONE2Icon? = nil, showsChevron: Bool = false, action: @escaping () -> Void) {
        self.init(action: action) {
            ONE2PillLabel(title: title, icon: icon, showsChevron: showsChevron)
        }
    }
}

struct ONE2PillLabel: View {
    let title: String
    let icon: ONE2Icon?
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: ONE2Space.s2) {
            if let icon {
                icon.image(size: ONE2Size.iconSmall).accessibilityHidden(true)
            }
            Text(title)
                .lineLimit(1)
            if showsChevron {
                ONE2Icon.chevronDown.image(size: ONE2Size.iconSmall).accessibilityHidden(true)
            }
        }
    }
}

#if DEBUG
private struct PillSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s3) {
            ONE2Pill(verbatim("Sana özel"), showsChevron: true) {}
            ONE2Pill(verbatim("Günler"), showsChevron: true) {}
            ONE2Pill(action: {}) {
                HStack(spacing: ONE2Space.s2) {
                    ONE2Icon.streak.image(size: ONE2Size.iconSmall)
                    Text(verbatim: "12").one2Type(.time).foregroundStyle(ONE2Color.brand)
                }
            }
            .accessibilityLabel(Text(verbatim: "12 günlük seri"))
        }
    }

    private func verbatim(_ s: String) -> String { s }
}

#Preview("Gece") { PillSamples().one2Preview(.gece) }
#Preview("Gün") { PillSamples().one2Preview(.gun) }
#Preview("AX3") { PillSamples().one2Preview(.ax3) }
#endif
