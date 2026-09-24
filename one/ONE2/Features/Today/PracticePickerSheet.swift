//
//  PracticePickerSheet.swift
//  ONE 2.0
//
//  "Pratiklerin › + Ekle": rehberli günlükler listesi. Eklenen işaretli,
//  premium olan kilitli (dokununca ONE+). Boş durum: eklenecek kalmadı.
//

import Foundation
import SwiftUI

struct PracticePickerSheet: View {
    let items: [PracticePickerItem]
    let onAdd: (PracticePickerItem) -> Void
    let onLocked: () -> Void
    let onClose: () -> Void

    var body: some View {
        V3SheetScreen(title: NSLocalizedString("one2.practices.pickerTitle", comment: "Add practice sheet title"),
                      onClose: onClose) {
            if items.allSatisfy(\.isAdded) {
                Text(NSLocalizedString("one2.practices.empty", comment: "No practices left to add"))
                    .bodyMD()
                    .foregroundColor(V3Tokens.mutedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: V3Tokens.spacingSM) {
                    ForEach(items) { item in
                        row(item)
                    }
                }
            }
        }
    }

    private func row(_ item: PracticePickerItem) -> some View {
        Button {
            if item.isLocked { onLocked() } else if !item.isAdded { onAdd(item) }
        } label: {
            HStack(alignment: .top, spacing: V3Tokens.spacingMD) {
                VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
                    Text(item.title)
                        .displayXS()
                        .foregroundColor(V3Tokens.ink)
                    Text(item.summary)
                        .bodySM()
                        .foregroundColor(V3Tokens.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let duration = item.durationLabel {
                        Text(duration)
                            .monoSM()
                            .foregroundColor(V3Tokens.faintText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: item.isAdded ? "checkmark" : (item.isLocked ? "lock" : "plus"))
                    .iconMD()
                    .foregroundColor(V3Tokens.ink)
                    .frame(width: V3Tokens.minTouchTarget, height: V3Tokens.minTouchTarget)
                    .accessibilityHidden(true)
            }
            .padding(V3Tokens.spacingLG)
            .multilineTextAlignment(.leading)
            .oneCardBackground(radius: V3Tokens.radiusTile)
            .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .disabled(item.isAdded)
        .accessibilityValue(item.isAdded
                            ? NSLocalizedString("one2.practices.added", comment: "Practice already added")
                            : (item.isLocked ? NSLocalizedString("one2.sheet.paywall", comment: "ONE+") : ""))
    }
}
