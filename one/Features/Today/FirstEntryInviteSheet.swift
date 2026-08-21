//
//  FirstEntryInviteSheet.swift
//  one
//
//  A4 — Retention planı: ilk entry sonrası Çevre davet kancası.
//  Hedef: yeni kullanıcı ONE'ı yalnız değil, en az 1 yakınıyla deneyimlesin.
//

import SwiftUI

struct FirstEntryInviteSheet: View {
    let moodColor: Color
    let onInvite: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            V3Tokens.paper.ignoresSafeArea()

            // Soft mood ambience
            RadialGradient(
                colors: [moodColor.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 480
            )
            .ignoresSafeArea()
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                // İkon — iki kesişen halka (yalnızlık → bağ kurma)
                ZStack {
                    Circle()
                        .stroke(moodColor.opacity(0.55), lineWidth: 1.4)
                        .frame(width: 86, height: 86)
                        .offset(x: -18)
                    Circle()
                        .stroke(V3Tokens.ink.opacity(0.55), lineWidth: 1.4)
                        .frame(width: 86, height: 86)
                        .offset(x: 18)
                }
                .scaleEffect(appeared ? 1.0 : 0.85)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, V3Tokens.spacingXL3)

                Text(NSLocalizedString("firstEntryInvite.eyebrow", comment: ""))
                    .monoSM(tracking: 1.6)
                    .foregroundColor(ONEBrand.kor.opacity(0.85))
                    .padding(.bottom, 10)

                Text(NSLocalizedString("firstEntryInvite.title", comment: ""))
                    .displayLG()
                    .foregroundColor(V3Tokens.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)

                Text(NSLocalizedString("firstEntryInvite.body", comment: ""))
                    .bodyMD()
                    .foregroundColor(V3Tokens.mutedText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, V3Tokens.spacingXL3)

                Spacer()

                VStack(spacing: V3Tokens.spacingMD) {
                    Button(action: onInvite) {
                        HStack(spacing: V3Tokens.spacingSM) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 15))
                            Text(NSLocalizedString("firstEntryInvite.invite", comment: ""))
                                .monoSM(tracking: 0.8)
                        }
                        .foregroundColor(ONEBrand.bone)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, V3Tokens.spacingLG)
                        .background(
                            RoundedRectangle(cornerRadius: V3Tokens.radiusCard)
                                .fill(V3Tokens.ink)
                        )
                    }

                    Button(action: onSkip) {
                        Text(NSLocalizedString("firstEntryInvite.skip", comment: ""))
                            .monoSM(tracking: 0.6)
                            .foregroundColor(V3Tokens.mutedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .contentShape(Rectangle())
                }
                .padding(.horizontal, V3Tokens.spacingXL2)
                .padding(.bottom, V3Tokens.spacingXL2)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
            }
        }
        .onAppear {
            withAnimation(ONEAnimation.panelSpring) {
                appeared = true
            }
        }
        .interactiveDismissDisabled(false)
    }
}

#Preview {
    FirstEntryInviteSheet(
        moodColor: Color(red: 0.95, green: 0.65, blue: 0.45),
        onInvite: {},
        onSkip: {}
    )
}
