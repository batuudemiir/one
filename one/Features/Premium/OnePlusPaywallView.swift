//
//  OnePlusPaywallView.swift
//  one
//
//  Prototip 32 — ONE+.
//

import SwiftUI

/// ONE+ tanıtımı.
///
/// Prototipin en önemli cümlesi ilk paragrafta: **"Günlük ritüel her zaman
/// ücretsiz kalacak. ONE+ sadece geçmişini okuma biçimini genişletir."**
/// Bu bir pazarlama süsü değil, ürünün sözleşmesi — kullanıcı ödemezse
/// hiçbir şey kaybetmiyor. Paywall'ı açanın ilk okuduğu şey bu olmalı ki
/// geri kalanı bir tehdit gibi değil, bir teklif gibi okunsun.
///
/// `PremiumManager.premiumEnabled` false olduğu sürece satın alma yok;
/// ekran yine de doğru bilgiyi gösteriyor ve buton "yakında" diyor.
struct OnePlusPaywallView: View {
    let onClose: () -> Void

    @State private var selectedPlan: Plan = .yearly

    enum Plan { case yearly, monthly }

    private struct Perk {
        let icon: String
        let title: String
        let detail: String
    }

    private var perks: [Perk] {
        [
            Perk(icon: "waveform",
                 title: NSLocalizedString("plus.perk.echo", comment: ""),
                 detail: NSLocalizedString("plus.perk.echoSub", comment: "")),
            Perk(icon: "square.grid.3x3",
                 title: NSLocalizedString("plus.perk.poster", comment: ""),
                 detail: NSLocalizedString("plus.perk.posterSub", comment: "")),
            Perk(icon: "music.note.list",
                 title: NSLocalizedString("plus.perk.playlist", comment: ""),
                 detail: NSLocalizedString("plus.perk.playlistSub", comment: "")),
            Perk(icon: "pencil",
                 title: NSLocalizedString("plus.perk.notes", comment: ""),
                 detail: NSLocalizedString("plus.perk.notesSub", comment: "")),
            Perk(icon: "flag",
                 title: NSLocalizedString("plus.perk.milestones", comment: ""),
                 detail: NSLocalizedString("plus.perk.milestonesSub", comment: ""))
        ]
    }

    var body: some View {
        ZStack(alignment: .top) {
            ONETokens.oneCream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("one+")
                        .monoLabel(tracking: 1.3)
                        .foregroundColor(ONETokens.oneStone)

                    Text(NSLocalizedString("plus.headline", comment: ""))
                        .displayLG()
                        .foregroundColor(ONETokens.oneInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)

                    // Ürünün sözleşmesi. Perk listesinden ÖNCE geliyor.
                    Text(NSLocalizedString("plus.promise", comment: ""))
                        .bodySM()
                        .foregroundColor(ONETokens.oneAsh)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 11)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(perks.enumerated()), id: \.offset) { _, perk in
                            perkRow(perk)
                        }
                    }
                    .padding(.top, ONETokens.spacingXL)

                    VStack(spacing: 8) {
                        planRow(
                            .yearly,
                            name: NSLocalizedString("plus.yearly", comment: ""),
                            price: NSLocalizedString("plus.yearlyPrice", comment: ""),
                            badge: NSLocalizedString("plus.yearlySave", comment: "")
                        )
                        planRow(
                            .monthly,
                            name: NSLocalizedString("plus.monthly", comment: ""),
                            price: NSLocalizedString("plus.monthlyPrice", comment: ""),
                            badge: nil
                        )
                    }
                    .padding(.top, ONETokens.spacingXL)

                    Button {
                        // PremiumManager stub — satın alma akışı henüz yok.
                    } label: {
                        Text(NSLocalizedString("plus.comingSoon", comment: ""))
                            .bodySMMedium()
                            .foregroundColor(ONETokens.oneCream)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule(style: .continuous).fill(ONETokens.oneInk))
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .opacity(0.4)
                    .padding(.top, ONETokens.spacingLG)

                    Text(NSLocalizedString("plus.legal", comment: ""))
                        .font(.system(size: 10.5))
                        .multilineTextAlignment(.center)
                        .foregroundColor(ONETokens.oneStone)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.top, ONETokens.spacingLG)
                }
                .padding(.horizontal, ONETokens.spacingXL)
                .padding(.top, 104)
                .padding(.bottom, 60)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Prototipte bu çubuğun zemini yok — paywall bir alt ekran
            // değil, üstüne açılan bir katman; ✕ ile kapanıyor.
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ONETokens.oneInk)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.7)))
                        .overlay(Circle().stroke(ONETokens.oneInk.opacity(0.09), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("general.close", comment: ""))

                Spacer()

                Button {
                    Task { await PremiumManager.shared.restorePurchases() }
                } label: {
                    Text(NSLocalizedString("plus.restore", comment: ""))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ONETokens.oneAsh)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ONETokens.spacingXL)
            .padding(.bottom, 12)
            .frame(height: 96, alignment: .bottom)
        }
    }

    // MARK: Parçalar

    private func perkRow(_ perk: Perk) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: perk.icon)
                .font(.system(size: 14))
                .foregroundColor(ONETokens.oneBrand)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(perk.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ONETokens.oneInk)
                Text(perk.detail)
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 9)
    }

    /// Prototip `.plan`: radyo + ad/fiyat + indirim rozeti; seçili olan
    /// mürekkep çerçeveli ve beyaz zeminli.
    private func planRow(
        _ plan: Plan,
        name: String,
        price: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            ONEHaptics.feelingSelected()
            withAnimation(.easeOut(duration: 0.15)) { selectedPlan = plan }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(
                        isSelected ? ONETokens.oneInk : ONETokens.oneInk.opacity(0.22),
                        lineWidth: 1.5
                    )
                    .frame(width: 19, height: 19)
                    .overlay {
                        if isSelected {
                            Circle().fill(ONETokens.oneInk).frame(width: 10, height: 10)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(ONETokens.oneInk)
                    Text(price)
                        .font(.system(size: 12))
                        .foregroundColor(ONETokens.oneAsh)
                }

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(ONETokens.oneBrand)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                    .stroke(
                        isSelected ? ONETokens.oneInk : ONETokens.oneInk.opacity(0.09),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
