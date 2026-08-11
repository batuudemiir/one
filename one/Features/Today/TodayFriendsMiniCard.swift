//
//  TodayFriendsMiniCard.swift
//  one
//

import SwiftUI
import CloudKit

struct TodayFriendsMiniCard: View {
    let data: CloudKitManager.FriendCircleData
    var onTap: () -> Void

    private var moodColorHex: String {
        data.share?["moodColor"] as? String
            ?? data.user["avatarColor"] as? String
            ?? "#888888"
    }
    private var displayName: String { data.user["displayName"] as? String ?? "?" }
    private var songName: String    { data.share?["songName"]   as? String ?? "" }
    private var artistName: String  { data.share?["artistName"] as? String ?? "" }
    private var moodWord: String    { (data.share?["moodWord"]  as? String ?? "").lowercased() }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: moodColorHex))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(V3Typography.sans(14, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(displayName)
                            .monoSM(tracking: 0.3)
                            .foregroundColor(V3Tokens.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if !moodWord.isEmpty {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: moodColorHex))
                                    .frame(width: 5, height: 5)
                                Text(moodWord)
                                    .monoLabel(tracking: 0.6)
                                    .foregroundColor(V3Tokens.mutedText)
                            }
                        }
                    }

                    Text(songName)
                        .bodySM()
                        .foregroundColor(V3Tokens.mutedText)
                        .lineLimit(1)

                    Text(artistName)
                        .monoLabel()
                        .foregroundColor(V3Tokens.faintText)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 230)
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
        .accessibilityLabel("\(displayName), \(songName), \(moodWord)")
    }
}
