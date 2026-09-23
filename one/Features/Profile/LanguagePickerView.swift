//
//  LanguagePickerView.swift
//  one
//
//  In-app language picker sheet. Presented from ProfileView.
//

import SwiftUI

struct LanguagePickerView: View {

    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // `List(.insetGrouped)` kalktı: sistem listesi kendi zeminini, kendi
        // satır yüksekliğini ve kendi ayraç payını getiriyordu. Kapatma
        // düğmesi de sağ üstteydi — uygulamanın geri kalanında sol üstte.
        V3SheetScreen(
            title: NSLocalizedString("profile.language", comment: ""),
            onClose: { dismiss() }
        ) {
            SettingsGroup {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                    LanguageRow(
                        language: language,
                        isSelected: languageManager.currentLanguage == language,
                        isLast: index == AppLanguage.allCases.count - 1
                    ) {
                        ONEHaptics.pick()
                        languageManager.setLanguage(language)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Dil satırı

/// Seçim satırı. `ReasonRow` ile aynı kalıp — chevron yok, sağda işaret var.
private struct LanguageRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: V3Tokens.spacingMD) {
                    Text(language.displayName)
                        .bodyMD()
                        .foregroundColor(V3Tokens.ink)

                    Spacer(minLength: V3Tokens.spacingSM)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .iconSM(weight: .semibold)
                            .foregroundColor(ONEBrand.kor)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 14)
                .frame(minHeight: V3Tokens.minTouchTarget)
                .contentShape(Rectangle())

                if !isLast {
                    Rectangle()
                        .fill(V3Tokens.hairline)
                        .frame(height: 1)
                        .padding(.leading, 15)
                }
            }
        }
        .buttonStyle(.onePressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    LanguagePickerView()
        .environmentObject(LanguageManager.shared)
}
