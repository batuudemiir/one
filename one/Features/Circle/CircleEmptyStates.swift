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

/// Arkadaşı olmayan kullanıcının gördüğü ekran.
///
/// Boş ekran değil, **değer önizlemesi**: bulanık örnek kartlar kullanıcıya ne
/// kaçırdığını gösterir. Solo D30 %0 / Sosyal D30 %20.7 — arkadaş edinmek bu
/// üründe bir tercih değil, kalmanın ön koşulu.
struct CircleEmptyState: View {
    @Binding var showAddFriend: Bool
    /// "Şimdilik tek başıma başla" — ritüele götürür. nil ise buton gizlenir.
    var onStartAlone: (() -> Void)? = nil

    /// Önizleme kartlarının renkleri — gerçek mood paletinden, sabit hex yok.
    private let previewMoods: [ONEMood] = [.sakin, .enerjik, .uzgun, .nostaljik, .derin]

    var body: some View {
        VStack(spacing: ONETokens.spacingXL) {
            Spacer(minLength: ONETokens.spacingMD)

            ZStack {
                previewStack
                    .blur(radius: 3.5)
                    .opacity(0.55)
                    .accessibilityHidden(true)

                VStack(spacing: ONETokens.spacingSM) {
                    Text(NSLocalizedString("circle.empty.previewTitle", comment: ""))
                        .displayMD()
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneInk)
                    Text(NSLocalizedString("circle.empty.previewSubtitle", comment: ""))
                        .bodySM()
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneAsh)
                }
                .padding(.horizontal, ONETokens.spacingXL)
            }

            VStack(spacing: ONETokens.spacingSM) {
                Button(action: { showAddFriend = true }) {
                    Text(NSLocalizedString("circle.empty.invite", comment: ""))
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

                if let onStartAlone {
                    Button(action: onStartAlone) {
                        Text(NSLocalizedString("circle.empty.startAlone", comment: ""))
                            .bodySMMedium()
                            .foregroundColor(ONETokens.oneAsh)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ONETokens.spacingMD)
                    }
                }
            }
            .padding(.horizontal, ONETokens.spacingXL2)

            Spacer(minLength: ONETokens.spacingXL4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Gerçek arkadaş kartlarının silüeti — içerik uydurmadan biçimi gösterir.
    private var previewStack: some View {
        VStack(spacing: ONETokens.spacingSM) {
            ForEach(previewMoods, id: \.self) { mood in
                HStack(spacing: ONETokens.spacingMD) {
                    Circle()
                        .fill(mood.color)
                        .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(ONETokens.oneInk.opacity(0.18))
                            .frame(width: 76, height: 11)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(ONETokens.oneInk.opacity(0.10))
                            .frame(width: 132, height: 9)
                    }
                    Spacer()
                }
                .padding(ONETokens.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: ONETokens.radiusFriend, style: .continuous)
                        .fill(ONETokens.oneCreamMid)
                )
            }
        }
        .padding(.horizontal, ONETokens.spacingXL)
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
