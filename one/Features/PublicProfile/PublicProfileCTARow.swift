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
        .padding(.horizontal, V3Tokens.spacingXL)
    }

    // MARK: - CTA buttons

    @ViewBuilder
    private var ctaButtons: some View {
        switch relationship {
        case .none:
            ctaButton(
                title: NSLocalizedString("circle.cta.add", comment: ""),
                foreground: ONEBrand.kor,
                background: ONEBrand.kor.opacity(0.10),
                action: onAdd
            )

        case .pendingOutgoing:
            ctaButton(
                title: NSLocalizedString("circle.toast.requestSent", comment: ""),
                foreground: V3Tokens.mutedText,
                background: V3Tokens.hairline,
                action: onCancelRequest
            )

        case .pendingIncoming:
            HStack(spacing: 10) {
                ctaButton(
                    title: NSLocalizedString("circle.cta.accept", comment: ""),
                    foreground: V3Tokens.success,
                    background: V3Tokens.success.opacity(0.10),
                    action: onAccept
                )
                ctaButton(
                    title: NSLocalizedString("circle.cta.decline", comment: ""),
                    foreground: V3Tokens.mutedText,
                    background: V3Tokens.hairline,
                    action: onDecline
                )
            }

        case .friend:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(V3Tokens.success)
                Text(NSLocalizedString("publicProfile.inYourCircle", comment: ""))
                    .bodySMMedium()
                    .foregroundStyle(V3Tokens.success)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(Capsule().fill(V3Tokens.success.opacity(0.08)))

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
                    .iconXS()
                Text(String(format: NSLocalizedString("publicProfile.mutualFriends", comment: ""), count))
                    .monoSM(tracking: 0)
            }
            .foregroundStyle(V3Tokens.mutedText)
            .padding(.horizontal, V3Tokens.spacingMD)
            .padding(.vertical, 6)
            .background(Capsule().fill(V3Tokens.hairline))
        }
    }

    // MARK: - Helper

    private func ctaButton(title: String, foreground: Color, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isWorking { V3Loading(.inline) }
                Text(title)
                    .bodySMMedium()
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .contentShape(Rectangle())
        .background(Capsule().fill(background))
        .disabled(isWorking)
    }
}
