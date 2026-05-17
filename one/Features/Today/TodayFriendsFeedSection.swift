//
//  TodayFriendsFeedSection.swift
//  one
//

import SwiftUI
import CloudKit

struct TodayFriendsFeedSection: View {
    let friendShares: [CloudKitManager.FriendCircleData]
    var onSeeAll: () -> Void
    var onFriendTap: (CloudKitManager.FriendCircleData) -> Void

    private var displayed: [CloudKitManager.FriendCircleData] { Array(friendShares.prefix(5)) }
    private var overflow: Int { max(0, friendShares.count - 5) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Çevrende Bugün")
                    .monoSM(tracking: 1.0)
                    .foregroundColor(ONETokens.oneAsh)
                Spacer()
                if !friendShares.isEmpty {
                    Button(action: onSeeAll) {
                        Text("Tümünü gör")
                            .monoLabel(tracking: 0.5)
                            .foregroundColor(ONETokens.oneBrand)
                    }
                }
            }

            if friendShares.isEmpty {
                HStack(spacing: 8) {
                    Text("💭")
                        .font(.system(size: 13))
                    Text("Arkadaşların henüz bugün paylaşmadı")
                        .bodySM()
                        .foregroundColor(ONETokens.oneStone)
                }
                .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(displayed) { item in
                            TodayFriendsMiniCard(data: item, onTap: { onFriendTap(item) })
                        }
                        if overflow > 0 {
                            Button(action: onSeeAll) {
                                VStack(spacing: 6) {
                                    Image(systemName: "arrow.right.circle")
                                        .bodyLG()
                                        .foregroundColor(ONETokens.oneBrand)
                                    Text("+\(overflow)")
                                        .monoSM(tracking: 0.5)
                                        .foregroundColor(ONETokens.oneAsh)
                                }
                                .frame(width: 80, height: 78)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(ONETokens.onePaper)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(ONETokens.oneSilver, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .transition(.opacity)
    }
}
