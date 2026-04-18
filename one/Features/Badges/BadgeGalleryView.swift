//
//  BadgeGalleryView.swift
//  one
//
//  Grid of all badges, showing unlocked vs locked state
//

import SwiftUI

struct BadgeGalleryView: View {
    @ObservedObject private var manager = BadgeManager.shared
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(BadgeCatalog.all) { badge in
                        BadgeCell(
                            badge: badge,
                            unlocked: manager.isUnlocked(badge.id),
                            unlockedAt: manager.unlockedAt(badge.id)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(ONETokens.oneCream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("badges.title", comment: ""))
                .monoBase(tracking: 2.0)
                .foregroundColor(ONETokens.oneAsh)
            Text("\(manager.unlocked.count) / \(BadgeCatalog.all.count)")
                .font(.custom("GeistMono-Regular", size: 28))
                .foregroundColor(ONETokens.oneInk)
            Text(NSLocalizedString("badges.subtitle", comment: ""))
                .font(.custom("GeistMono-Regular", size: 11))
                .foregroundColor(ONETokens.oneAsh)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
}

private struct BadgeCell: View {
    let badge: Badge
    let unlocked: Bool
    let unlockedAt: Date?

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(unlocked ? ONETokens.oneInk.opacity(0.08) : ONETokens.oneCreamMid)
                    .frame(width: 72, height: 72)
                Image(systemName: unlocked ? badge.iconSystemName : "lock")
                    .font(.system(size: 26, weight: .light))
                    .foregroundColor(unlocked ? ONETokens.oneInk : ONETokens.oneStone)
            }

            VStack(spacing: 4) {
                Text(badge.title)
                    .font(.custom("GeistMono-Regular", size: 12))
                    .tracking(0.5)
                    .foregroundColor(unlocked ? ONETokens.oneInk : ONETokens.oneAsh)
                    .multilineTextAlignment(.center)
                Text(badge.description)
                    .font(.custom("GeistMono-Regular", size: 10))
                    .foregroundColor(ONETokens.oneStone)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(ONETokens.oneInk.opacity(unlocked ? 0.15 : 0.06), lineWidth: 1)
        )
        .opacity(unlocked ? 1.0 : 0.6)
    }
}
