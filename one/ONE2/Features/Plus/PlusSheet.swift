//
//  PlusSheet.swift
//  ONE 2.0
//
//  + sayfası (README Bilgi mimarisi): Boş sayfa, Mood check-in, Günlük
//  önerisi, Şablonlar, Kütüphane. Seçim kabuğa bildirilir; kabuk sayfayı
//  kapatır ve hedefi açar (Features birbirini doğrudan açmaz).
//

import SwiftUI

nonisolated enum PlusAction: CaseIterable, Hashable, Sendable {
    case blank, checkIn, dailyPrompt, templates, library
}

struct PlusSheet: View {
    let onSelect: (PlusAction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(PlusAction.allCases, id: \.self) { action in
                    PlusRow(action: action) { onSelect(action) }
                }
            }
            .padding(.horizontal, ONE2Space.gutter)
            .padding(.vertical, ONE2Space.s6)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(ONE2Radius.xl)
        .presentationBackground(ONE2Color.surface)
    }
}

private struct PlusRow: View {
    let action: PlusAction
    let onTap: () -> Void

    private var content: (icon: ONE2Icon, title: String, detail: String) {
        switch action {
        case .blank:       return (.blankPage, one2String("one2.plus.blank"), one2String("one2.plus.blank.detail"))
        case .checkIn:     return (.checkIn, one2String("one2.plus.checkIn"), one2String("one2.plus.checkIn.detail"))
        case .dailyPrompt: return (.prompt, one2String("one2.plus.prompt"), one2String("one2.plus.prompt.detail"))
        case .templates:   return (.templates, one2String("one2.plus.templates"), one2String("one2.plus.templates.detail"))
        case .library:     return (.library, one2String("one2.plus.library"), one2String("one2.plus.library.detail"))
        }
    }

    var body: some View {
        let c = content
        Button(action: onTap) {
            HStack(spacing: ONE2Space.s4) {
                c.icon.image()
                    .foregroundStyle(ONE2Color.ink)
                    .frame(width: ONE2Size.control, height: ONE2Size.control)
                    .background(ONE2Color.raised, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: ONE2Space.s1) {
                    Text(c.title).one2Type(.headline).foregroundStyle(ONE2Color.ink)
                    Text(c.detail).one2Type(.bodySm).foregroundStyle(ONE2Color.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ONE2Icon.chevronRight.image(size: ONE2Size.iconSmall)
                    .foregroundStyle(ONE2Color.inkFaint)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, ONE2Space.s3)
            .frame(minHeight: ONE2Size.minTouch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.one2Press)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
private struct PlusSheetHost: View {
    var body: some View {
        ONE2Color.ground.ignoresSafeArea()
            .sheet(isPresented: .constant(true)) { PlusSheet { _ in } }
    }
}

#Preview("Gece") { PlusSheetHost().preferredColorScheme(.dark) }
#Preview("Gün") { PlusSheetHost().preferredColorScheme(.light) }
#Preview("AX3") { PlusSheetHost().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#endif
