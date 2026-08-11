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
                    .foregroundColor(V3Tokens.mutedText)
                Spacer()
                if !friendShares.isEmpty {
                    Button(action: onSeeAll) {
                        Text("Tümünü gör")
                            .monoLabel(tracking: 0.5)
                            .foregroundColor(ONEBrand.kor)
                    }
                }
            }

            if friendShares.isEmpty {
                HStack(spacing: 8) {
                    Text("💭")
                        .font(V3Typography.sans(13))
                    Text("Arkadaşların henüz bugün paylaşmadı")
                        .bodySM()
                        .foregroundColor(V3Tokens.faintText)
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
                                        .foregroundColor(ONEBrand.kor)
                                    Text("+\(overflow)")
                                        .monoSM(tracking: 0.5)
                                        .foregroundColor(V3Tokens.mutedText)
                                }
                                .frame(width: 80, height: 78)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(V3Tokens.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(V3Tokens.hairline, lineWidth: 1)
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
