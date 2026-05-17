//
//  PublicProfileCTARow.swift
//  one
//
//  5 ilişki durumuna göre CTA buton(lar)ı + mutual friends chip.
//

import SwiftUI
import CloudKit

struct PublicProfileCTARow: View {
    let relationship: PublicProfileRelationship
    let mutualFriendCount: Int?
    let isWorking: Bool

    var onAdd: () -> Void
    var onCancelRequest: () -> Void
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ctaButtons
            mutualChip
        }
        .padding(.horizontal, 20)
    }

    // MARK: - CTA buttons

    @ViewBuilder
    private var ctaButtons: some View {
        switch relationship {
        case .none:
            ctaButton(
                title: "Çevrene ekle",
                foreground: ONETokens.oneBrand,
                background: ONETokens.oneBrand.opacity(0.10),
                action: onAdd
            )

        case .pendingOutgoing:
            ctaButton(
                title: "İstek gönderildi",
                foreground: ONETokens.oneAsh,
                background: ONETokens.oneSilver,
                action: onCancelRequest
            )

        case .pendingIncoming:
            HStack(spacing: 10) {
                ctaButton(
                    title: "Kabul et",
                    foreground: ONETokens.oneGreen,
                    background: ONETokens.oneGreen.opacity(0.10),
                    action: onAccept
                )
                ctaButton(
                    title: "Reddet",
                    foreground: ONETokens.oneAsh,
                    background: ONETokens.oneSilver,
                    action: onDecline
                )
            }

        case .friend:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ONETokens.oneGreen)
                Text("Çevrende")
                    .bodySMMedium()
                    .foregroundStyle(ONETokens.oneGreen)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(Capsule().fill(ONETokens.oneGreen.opacity(0.08)))

        case .self_, .blockedByMe, .blockedMe:
            EmptyView()
        }
    }

    // MARK: - Mutual friends chip

    @ViewBuilder
    private var mutualChip: some View {
        if let count = mutualFriendCount, count > 0 {
            HStack(spacing: 5) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                Text("\(count) ortak arkadaşınız var")
                    .monoSM(tracking: 0)
            }
            .foregroundStyle(ONETokens.oneAsh)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(ONETokens.oneSilver))
        }
    }

    // MARK: - Helper

    private func ctaButton(title: String, foreground: Color, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isWorking { ProgressView().scaleEffect(0.75) }
                Text(title)
                    .bodySMMedium()
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .background(Capsule().fill(background))
        .disabled(isWorking)
    }
}
