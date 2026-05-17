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
                    .fill(ONETokens.oneCharcoal)
                    .frame(width: 72, height: 72)
                Text("✦")
                    .font(.system(size: 32))
                    .foregroundColor(ONETokens.oneCream)
            }
            .padding(.top, ONETokens.spacingXL)

            Spacer().frame(height: ONETokens.spacingLG)

            Text(NSLocalizedString("update.title", comment: ""))
                .displaySM()
                .foregroundColor(ONETokens.oneCharcoal)

            Spacer().frame(height: ONETokens.spacingSM)

            Text(String(format: NSLocalizedString("update.body", comment: ""), newVersion))
                .bodyMD()
                .foregroundColor(ONETokens.oneAsh)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ONETokens.spacingXL)

            Spacer().frame(height: 6)

            Text(String(format: NSLocalizedString("update.current", comment: ""), currentVersion))
                .monoLabel(tracking: 0.5)
                .foregroundColor(ONETokens.oneStone)

            Spacer().frame(height: ONETokens.spacingXL)

            // Güncelle butonu
            Button(action: onUpdate) {
                Text(NSLocalizedString("update.cta", comment: ""))
                    .monoSM(tracking: 1.4)
                    .foregroundColor(ONETokens.oneCream)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(ONETokens.oneCharcoal)
                    .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard, style: .continuous))
            }
            .padding(.horizontal, ONETokens.spacingLG)

            Spacer().frame(height: ONETokens.spacingSM)

            // Sonra hatırlat — zorla güncelleme modunda gizli
            if !isForced {
                Button(action: onDismiss) {
                    Text(NSLocalizedString("update.later", comment: ""))
                        .monoSM(tracking: 0.8)
                        .foregroundColor(ONETokens.oneAsh)
                }
                .padding(.bottom, ONETokens.spacingLG)
            } else {
                Spacer().frame(height: ONETokens.spacingLG)
            }
        }
        .frame(maxWidth: .infinity)
        .background(ONETokens.oneCream.ignoresSafeArea())
    }
}
