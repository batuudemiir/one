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
        NavigationView {
            List(AppLanguage.allCases) { language in
                Button {
                    languageManager.setLanguage(language)
                    dismiss()
                } label: {
                    HStack {
                        Text(language.displayName)
                            .font(ONETypography.bodyLG)
                            .foregroundColor(V3Tokens.ink)
                        Spacer()
                        if languageManager.currentLanguage == language {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ONEBrand.kor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: ONETokens.minTouchTarget)
            }
            .listStyle(.insetGrouped)
            .navigationTitle(NSLocalizedString("profile.language", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(V3Tokens.mutedText)
                            .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
    }
}

#Preview {
    LanguagePickerView()
        .environmentObject(LanguageManager.shared)
}
