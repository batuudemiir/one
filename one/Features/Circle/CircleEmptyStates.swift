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
    /// Frekans'ın açılması için gereken arkadaş sayısı ve mevcut sayı.
    /// Çevre tek kişiyle çalışmıyor — bir "frekans" ancak birkaç kişiyle
    /// oluşuyor. İlerleme göstermek, kapıyı ceza olmaktan çıkarıyor.
    var friendCount: Int = 0
    var requiredFriends: Int = 3
    /// "Şimdilik tek başıma başla" — ritüele götürür. nil ise buton gizlenir.
    var onStartAlone: (() -> Void)? = nil

    /// Önizleme kartlarının renkleri — gerçek mood paletinden, sabit hex yok.
    private let previewMoods: [ONEMood] = [.sakin, .enerjik, .uzgun, .nostaljik, .derin]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ONETokens.spacingXL) {
                ZStack {
                    previewStack
                        .blur(radius: 3.6)
                        .opacity(0.55)
                        .accessibilityHidden(true)

                    // Perde. Prototipte metin bulanık kartların üstünde değil,
                    // krem bir gradyanın üstünde duruyor — bu olmadan başlık
                    // kartlarla karışıp okunmaz hale geliyordu.
                    LinearGradient(
                        colors: [
                            ONEBrand.bone.opacity(0.35),
                            ONEBrand.bone.opacity(0.90)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(spacing: ONETokens.spacingSM) {
                        Text(NSLocalizedString("circle.empty.previewTitle", comment: ""))
                            .displayMD()
                            .multilineTextAlignment(.center)
                            .foregroundColor(V3Tokens.ink)
                        Text(NSLocalizedString("circle.empty.previewSubtitle", comment: ""))
                            .bodySM()
                            .multilineTextAlignment(.center)
                            .foregroundColor(V3Tokens.mutedText)
                    }
                    .padding(.horizontal, ONETokens.spacingXL)
                }
                .fixedSize(horizontal: false, vertical: true)

                if requiredFriends > 0 {
                    progressRow
                        .padding(.horizontal, ONETokens.spacingXL2)
                        .padding(.bottom, ONETokens.spacingSM)
                }

                VStack(spacing: ONETokens.spacingSM) {
                    // Prototip: düz marka rengi, 26pt yarıçap, 44pt min yükseklik.
                    // Gradyan yoktu — tek düz renk daha net bir çağrı.
                    Button(action: { showAddFriend = true }) {
                        Text(NSLocalizedString("circle.empty.invite", comment: ""))
                            .bodySMMedium()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                Capsule(style: .continuous).fill(ONEBrand.kor)
                            )
                    }
                    .accessibilityLabel(NSLocalizedString("accessibility.circle.setupCircle", comment: ""))

                    if let onStartAlone {
                        Button(action: onStartAlone) {
                            Text(NSLocalizedString("circle.empty.startAlone", comment: ""))
                                .bodySMMedium()
                                .foregroundColor(V3Tokens.mutedText)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
                .padding(.horizontal, ONETokens.spacingXL2)

                // Kapanış: davetin neden işe yaradığını söyleyen tek cümle.
                VStack(spacing: ONETokens.spacingXL) {
                    Rectangle()
                        .fill(V3Tokens.ink.opacity(0.09))
                        .frame(height: 1)

                    Text(NSLocalizedString("circle.empty.closing", comment: ""))
                        .bodySM()
                        .multilineTextAlignment(.center)
                        .foregroundColor(V3Tokens.mutedText)
                        .padding(.horizontal, ONETokens.spacingXL)
                }
                .padding(.horizontal, ONETokens.spacingXL2)
            }
            .padding(.top, ONETokens.spacingLG)
            // Sekme çubuğu içeriği kesmesin — ekran görüntüsünde "şimdilik tek
            // başıma başla" dock'un altında kalıyordu.
            .padding(.bottom, 116)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Kaç kişi kaldı. Sayı değil, üç nokta — "2 kişi daha" demek yerine
    /// ne kadar yaklaştığını göstermek daha az ödev gibi duruyor.
    private var progressRow: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach(0..<requiredFriends, id: \.self) { index in
                    Circle()
                        .fill(index < friendCount
                              ? ONETokens.oneBrand
                              : V3Tokens.ink.opacity(0.12))
                        .frame(width: 9, height: 9)
                }
            }

            Text(String(
                format: NSLocalizedString("circle.gateProgress", comment: ""),
                max(requiredFriends - friendCount, 0)
            ))
            .bodyXS()
            .foregroundColor(V3Tokens.mutedText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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
                            .fill(V3Tokens.ink.opacity(0.18))
                            .frame(width: 76, height: 11)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(V3Tokens.ink.opacity(0.10))
                            .frame(width: 132, height: 9)
                    }
                    Spacer()
                }
                .padding(ONETokens.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: ONETokens.radiusFriend, style: .continuous)
                        .fill(V3Tokens.surface)
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
                    .foregroundColor(V3Tokens.mutedText)

                VStack(spacing: ONETokens.spacingSM) {
                    Text(NSLocalizedString("circle.iCloudRequired", comment: ""))
                        .displayMD()
                        .foregroundColor(V3Tokens.ink)

                    Text(NSLocalizedString("circle.iCloudMessage", comment: ""))
                        .monoSM(tracking: 0)
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneCharcoal)
                        .padding(.horizontal, 40)

#if DEBUG
                    Text("Debug: CloudKit durumu kontrol ediliyor...")
                        .monoMicro(tracking: 0)
                        .foregroundColor(V3Tokens.faintText)
                        .padding(.top, ONETokens.spacingSM)
#endif
                }
            }

            Spacer()

            VStack(spacing: ONETokens.spacingMD) {
                Button(action: onRetry) {
                    Text(NSLocalizedString("circle.tryAgain", comment: ""))
                        .monoBase(tracking: 1.0)
                        .foregroundColor(V3Tokens.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ONETokens.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(V3Tokens.mutedText, lineWidth: 1)
                        )
                }

                Button(action: onOpenSettings) {
                    Text(NSLocalizedString("circle.goToSettings", comment: ""))
                        .monoBase(tracking: 1.0)
                        .foregroundColor(ONEBrand.bone)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ONETokens.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(V3Tokens.ink)
                        )
                }
            }
            .padding(.horizontal, ONETokens.spacingXL)
            .padding(.bottom, ONETokens.spacingXL4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
