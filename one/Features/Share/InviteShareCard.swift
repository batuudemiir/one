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

    /// v3 nötr paletiyle uyumlu paper zemin — koyu değil.
    private let paper: Color = Color(hex: "#FBFAF7")
    private let ink: Color = Color(hex: "#14141A")
    private let muted: Color = Color(hex: "#6B6B78")
    private let faint: Color = Color(hex: "#A8A59C")
    private let hairline: Color = Color(hex: "#E6E3DB")
    private let kor: Color = Color(hex: "#FF3B1F")

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
                Text("ONE")
                    .font(.system(size: 22, weight: .black))
                    .tracking(-0.6)
                    .foregroundColor(kor)
                Rectangle().fill(hairline).frame(height: 1)
            }
            .padding(.horizontal, 40)
            .padding(.top, 44)

            Spacer(minLength: 0)

            // QR bloğu — spec: 110pt.
            VStack(spacing: 22) {
                qrBlock(size: 132)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(hairline, lineWidth: 1)
                            )
                    )

                VStack(spacing: 6) {
                    Text(userName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(ink)
                        .lineLimit(1)
                    Text(shortLink)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .tracking(0.4)
                        .foregroundColor(muted)
                }
            }

            Spacer(minLength: 0)

            // Footer: "7 gün geçerli" microtext.
            Text("7 GÜN GEÇERLİ")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(faint)
                .padding(.bottom, 44)
        }
    }

    // MARK: - Post layout (1:1)

    private var postLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("ONE")
                    .font(.system(size: 18, weight: .black))
                    .tracking(-0.4)
                    .foregroundColor(kor)
                Spacer()
                Text(shortLink)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundColor(muted)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)

            Rectangle().fill(hairline).frame(height: 1).padding(.horizontal, 32).padding(.top, 12)

            Spacer(minLength: 0)

            HStack(spacing: 32) {
                qrBlock(size: 132)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(hairline, lineWidth: 1)
                            )
                    )

                VStack(alignment: .leading, spacing: 10) {
                    Text(userName)
                        .font(.system(size: 24, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundColor(ink)
                        .lineLimit(1)
                    Text("Beni ONE'da ekle")
                        .font(.system(size: 13))
                        .foregroundColor(muted)
                    Text("7 GÜN GEÇERLİ")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(faint)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 40)

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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(inviteCode.uppercased())
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
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
