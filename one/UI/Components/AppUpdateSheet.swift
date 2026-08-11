//
//  AppUpdateSheet.swift
//  one
//

import SwiftUI

struct AppUpdateSheet: View {
    let currentVersion: String
    let newVersion: String
    let onUpdate: () -> Void
    let onDismiss: () -> Void
    var isForced: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(V3Tokens.mutedText)
                    .frame(width: 72, height: 72)
                Text("✦")
                    .font(V3Typography.sans(32))
                    .foregroundColor(ONEBrand.bone)
            }
            .padding(.top, ONETokens.spacingXL)

            Spacer().frame(height: ONETokens.spacingLG)

            Text(NSLocalizedString("update.title", comment: ""))
                .displaySM()
                .foregroundColor(V3Tokens.mutedText)

            Spacer().frame(height: ONETokens.spacingSM)

            Text(String(format: NSLocalizedString("update.body", comment: ""), newVersion))
                .bodyMD()
                .foregroundColor(V3Tokens.mutedText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ONETokens.spacingXL)

            Spacer().frame(height: 6)

            Text(String(format: NSLocalizedString("update.current", comment: ""), currentVersion))
                .monoLabel(tracking: 0.5)
                .foregroundColor(V3Tokens.faintText)

            Spacer().frame(height: ONETokens.spacingXL)

            // Güncelle butonu
            Button(action: onUpdate) {
                Text(NSLocalizedString("update.cta", comment: ""))
                    .monoSM(tracking: 1.4)
                    .foregroundColor(ONEBrand.bone)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(V3Tokens.mutedText)
                    .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard, style: .continuous))
            }
            .padding(.horizontal, ONETokens.spacingLG)

            Spacer().frame(height: ONETokens.spacingSM)

            // Sonra hatırlat — zorla güncelleme modunda gizli
            if !isForced {
                Button(action: onDismiss) {
                    Text(NSLocalizedString("update.later", comment: ""))
                        .monoSM(tracking: 0.8)
                        .foregroundColor(V3Tokens.mutedText)
                }
                .padding(.bottom, ONETokens.spacingLG)
            } else {
                Spacer().frame(height: ONETokens.spacingLG)
            }
        }
        .frame(maxWidth: .infinity)
        .background(ONEBrand.bone.ignoresSafeArea())
    }
}
