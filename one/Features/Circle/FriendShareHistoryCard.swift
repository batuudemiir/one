//
//  FriendShareHistoryCard.swift
//  one
//
//  Compact card showing a friend's past daily share (ONE+ Premium)
//

import SwiftUI
import CloudKit

struct FriendShareHistoryCard: View {
    let record: CKRecord

    @State private var isExpanded = false

    private var songName: String { record["songName"] as? String ?? "" }
    private var artistName: String { record["artistName"] as? String ?? "" }
    private var moodWord: String { record["moodWord"] as? String ?? "" }
    private var moodColorHex: String { record["moodColor"] as? String ?? "#607D8B" }
    private var dateValue: Date? { record["date"] as? Date }
    private var dailyNote: String? { record["dailyNote"] as? String }
    private var feeling: String? { record["feelingLabel"] as? String }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: ONETokens.spacingMD) {
                // Mood color dot
                Circle()
                    .fill(Color(hex: moodColorHex))
                    .frame(width: 12, height: 12)

                // Song info
                VStack(alignment: .leading, spacing: 2) {
                    Text(songName)
                        .font(ONETypography.bodySMMedium)
                        .foregroundStyle(V3Tokens.ink)
                        .lineLimit(1)

                    Text(artistName)
                        .font(ONETypography.bodyXS)
                        .foregroundStyle(V3Tokens.mutedText)
                        .lineLimit(1)
                }

                Spacer()

                // Date
                if let date = dateValue {
                    Text(formatDate(date))
                        .font(ONETypography.monoLabel)
                        .foregroundStyle(V3Tokens.faintText)
                }

                // Expand indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(V3Tokens.faintText)
            }
            .padding(ONETokens.spacingMD)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(ONEAnimation.micro) {
                    isExpanded.toggle()
                }
            }

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: ONETokens.spacingSM) {
                    // Mood label
                    if !moodWord.isEmpty {
                        HStack(spacing: ONETokens.spacingXS) {
                            Circle()
                                .fill(Color(hex: moodColorHex))
                                .frame(width: 8, height: 8)
                            Text(moodWord)
                                .font(ONETypography.monoBase)
                                .foregroundStyle(ONETokens.oneCharcoal)
                        }
                    }

                    // Feeling
                    if let feeling, !feeling.isEmpty {
                        Text(feeling)
                            .font(ONETypography.bodyXS)
                            .foregroundStyle(V3Tokens.mutedText)
                    }

                    // Note
                    if let note = dailyNote, !note.isEmpty {
                        Text(note)
                            .font(ONETypography.bodyXS)
                            .foregroundStyle(V3Tokens.mutedText)
                            .lineLimit(4)
                    }
                }
                .padding(.horizontal, ONETokens.spacingMD)
                .padding(.bottom, ONETokens.spacingMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(V3Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCard))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}
