//
//  InviteShareCard.swift
//  one
//
//  v3 spec — davet kartı: paper zemin, 110pt QR, kısa link + "7 gün geçerli".
//  Eski BeReal-tarzı deep black kart iptal edildi (spec dışı).
//
//  Rendering: 360×640 (story) veya 540×540 (post) point boyutunda, 3x scale
//  ile 1080×1920 / 1620×1620 piksel export.
//

import SwiftUI

enum ShareFormat {
    case story
    case post
}

struct InviteShareCard: View {
    let inviteCode: String
    let userName: String
    var format: ShareFormat = .story

    // Palet `V3Tokens.Export`'tan geliyor. Burada altı ayrı `private let`
    // olarak duruyordu; değerler zamanla kaydı (`faint` hâlâ erişilebilirlik
    // düzeltmesi öncesi #A8A59C idi — 2.36:1) ve kart uygulamanın geri
    // kalanından ayrı bir palete demirlemişti.
    private let paper    = V3Tokens.Export.paper
    private let ink      = V3Tokens.Export.ink
    private let muted    = V3Tokens.Export.muted
    private let faint    = V3Tokens.Export.faint
    private let hairline = V3Tokens.Export.hairline

    var body: some View {
        ZStack {
            paper
            switch format {
            case .story:  storyLayout
            case .post:   postLayout
            }
        }
        .frame(
            width:  format == .story ? 360 : 540,
            height: format == .story ? 640 : 540
        )
    }

    // MARK: - Story layout (9:16)

    private var storyLayout: some View {
        VStack(spacing: 0) {
            // Top: kor wordmark + hairline (spec — kare rozet değil, kor metin).
            VStack(spacing: 10) {
                ONEWordmark(size: 22, tone: .kor)
                Rectangle().fill(hairline).frame(height: 1)
            }
            .padding(.horizontal, V3Tokens.spacingXL4)
            .padding(.top, 44)

            Spacer(minLength: 0)

            // QR bloğu — spec: 110pt.
            VStack(spacing: V3Tokens.spacingXL) {
                qrBlock(size: 132)
                    .padding(V3Tokens.spacingXL)
                    .background(
                        RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                            .fill(V3Tokens.Export.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                                    .stroke(hairline, lineWidth: 1)
                            )
                    )

                VStack(spacing: 6) {
                    Text(userName)
                        .font(V3Typography.sansFixed(20, weight: .semibold))
                        .foregroundColor(ink)
                        .lineLimit(1)
                    Text(shortLink)
                        .font(V3Typography.monoFixed(13, weight: .medium))
                        .tracking(0.4)
                        .foregroundColor(muted)
                }
            }

            Spacer(minLength: 0)

            // Footer: "7 gün geçerli" microtext.
            Text(NSLocalizedString("invite.validSevenDays", comment: ""))
                .font(V3Typography.monoFixed(10))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundColor(faint)
                .padding(.bottom, 44)
        }
    }

    // MARK: - Post layout (1:1)

    private var postLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ONEWordmark(size: 18, tone: .kor)
                Spacer()
                Text(shortLink)
                    .font(V3Typography.monoFixed(12, weight: .medium))
                    .tracking(0.4)
                    .foregroundColor(muted)
            }
            .padding(.horizontal, V3Tokens.spacingXL3)
            .padding(.top, V3Tokens.spacingXL3)

            Rectangle().fill(hairline).frame(height: 1).padding(.horizontal, V3Tokens.spacingXL3).padding(.top, V3Tokens.spacingMD)

            Spacer(minLength: 0)

            HStack(spacing: V3Tokens.spacingXL3) {
                qrBlock(size: 132)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: V3Tokens.radiusPanel - 2, style: .continuous)
                            .fill(V3Tokens.Export.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: V3Tokens.radiusPanel - 2, style: .continuous)
                                    .stroke(hairline, lineWidth: 1)
                            )
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Text(userName)
                        .font(V3Typography.sansFixed(24, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundColor(ink)
                        .lineLimit(1)
                    Text(NSLocalizedString("invite.addMeOnONE", comment: "Beni ONE'da ekle"))
                        .font(V3Typography.sansFixed(13))
                        .foregroundColor(muted)
                    Text(NSLocalizedString("invite.validSevenDays", comment: ""))
                        .font(V3Typography.monoFixed(10))
                        .tracking(1.5)
                        .textCase(.uppercase)
                        .foregroundColor(faint)
                        .padding(.top, V3Tokens.spacingXS)
                }
            }
            .padding(.horizontal, V3Tokens.spacingXL4)

            Spacer(minLength: 0)
        }
    }

    // MARK: - QR helper

    /// 110pt QR — spec değeri. Kod okunamıyorsa (CIFilter fail) placeholder
    /// karesi çiziliyor, kısa link ile davet hâlâ mümkün.
    private func qrBlock(size: CGFloat) -> some View {
        Group {
            if let img = QRCodeGenerator.inviteQR(code: inviteCode, size: size * 2) {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                RoundedRectangle(cornerRadius: V3Tokens.radiusChip, style: .continuous)
                    .strokeBorder(hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(inviteCode.uppercased())
                            .font(V3Typography.monoFixed(14, weight: .semibold))
                            .foregroundColor(ink)
                    )
            }
        }
    }

    /// Kısa link biçimi spec: `one.app/f/batu-7km2`. Domain uygulama sabiti.
    private var shortLink: String {
        let handle = userName
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "tr_TR"))
            .filter { $0.isLetter || $0.isNumber }
            .prefix(8)
        let code = inviteCode.lowercased().prefix(4)
        return "one.app/f/\(handle)-\(code)"
    }
}
