//
//  CircleEmptyStates.swift
//  one
//
//  Empty + CloudKit-unavailable states for Circle.
//  Pure View structs — depend only on injected bindings/closures.
//  Extracted from CircleView.swift in Faz 3.1 (2026-04-26).
//

import SwiftUI

// MARK: - Empty State (no friends yet)

struct CircleEmptyState: View {
    @Binding var showAddFriend: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: ONETokens.spacingXL) {
                // Mascot
                VStack(spacing: ONETokens.spacingXL) {
                    OneMascotView(pose: .noState, size: 120, message: "")

                    VStack(spacing: ONETokens.spacingSM) {
                        Text("Çevren henüz boş.")
                            .displayMD()
                            .foregroundColor(ONETokens.oneInk)
                        Text("Bir arkadaşını davet et,\nonun moodunu gör.")
                            .bodySM()
                            .multilineTextAlignment(.center)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }

                // Buttons
                VStack(spacing: ONETokens.spacingMD) {
                    Button(action: { showAddFriend = true }) {
                        Text("Davet Et")
                            .bodySMMedium()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ONETokens.spacingMD)
                            .background(
                                LinearGradient(
                                    colors: [ONETokens.oneBrand, ONETokens.oneBrandLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityLabel(NSLocalizedString("accessibility.circle.setupCircle", comment: ""))
                    .padding(.horizontal, ONETokens.spacingXL2)
                }
            }
            .padding(.horizontal, ONETokens.spacingXL)

            Spacer()
            Spacer() // double spacer → content biraz yukarda durur (nav bar'dan uzak)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - CloudKit Unavailable

struct CircleCloudKitUnavailableState: View {
    @ObservedObject var cloudKitManager: CloudKitManager
    let onRetry: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: ONETokens.spacingXL) {
            Spacer()

            VStack(spacing: ONETokens.spacingLG) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 56, weight: .ultraLight))
                    .foregroundColor(ONETokens.oneAsh)

                VStack(spacing: ONETokens.spacingSM) {
                    Text(NSLocalizedString("circle.iCloudRequired", comment: ""))
                        .displayMD()
                        .foregroundColor(ONETokens.oneInk)

                    Text(NSLocalizedString("circle.iCloudMessage", comment: ""))
                        .monoSM(tracking: 0)
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneCharcoal)
                        .padding(.horizontal, 40)

#if DEBUG
                    Text("Debug: CloudKit durumu kontrol ediliyor...")
                        .monoMicro(tracking: 0)
                        .foregroundColor(ONETokens.oneStone)
                        .padding(.top, ONETokens.spacingSM)
#endif
                }
            }

            Spacer()

            VStack(spacing: ONETokens.spacingMD) {
                Button(action: onRetry) {
                    Text(NSLocalizedString("circle.tryAgain", comment: ""))
                        .monoBase(tracking: 1.0)
                        .foregroundColor(ONETokens.oneInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ONETokens.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ONETokens.oneAsh, lineWidth: 1)
                        )
                }

                Button(action: onOpenSettings) {
                    Text(NSLocalizedString("circle.goToSettings", comment: ""))
                        .monoBase(tracking: 1.0)
                        .foregroundColor(ONETokens.oneCream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ONETokens.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ONETokens.oneInk)
                        )
                }
            }
            .padding(.horizontal, ONETokens.spacingXL)
            .padding(.bottom, ONETokens.spacingXL4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
