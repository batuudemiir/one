//
//  EchoData.swift
//  One - Günlük Mood
//

import SwiftUI

// MARK: - Echo Data Models

// Çevre ile aynı şarkı eşleşmesi
struct CircleSyncMatch: Identifiable {
    let id: UUID
    let date: Date
    let dateLabel: String       // "14 Mar" gibi
    let songName: String
    let artistName: String
    let friendDisplayName: String
    let moodColorHex: String    // kendi mood rengi
}

struct EchoData {
    let weekColors: [Color?]            // 7 gün, nil = boş
    let dominantFeeling: FeelingType?
    let repeatedSongs: [RepeatedSong]
    let silentDays: Int
    let silentDates: [String]
    let longestStreak: StreakInfo
    let currentStreak: Int
    let hourDistribution: [Int: Int]    // saat: seçim sayısı (0-23)
    let circleSyncMatches: [CircleSyncMatch]   // CloudKit'ten gelen gerçek eşleşmeler
    let last30DaysColors: [Color?]

    var syncCount: Int { circleSyncMatches.count }

    static let empty = EchoData(
        weekColors: Array(repeating: nil, count: 7),
        dominantFeeling: nil,
        repeatedSongs: [],
        silentDays: 0,
        silentDates: [],
        longestStreak: StreakInfo(days: 0, startDate: "—", endDate: "—", colors: []),
        currentStreak: 0,
        hourDistribution: [:],
        circleSyncMatches: [],
        last30DaysColors: Array(repeating: nil, count: 30)
    )

    static func mock() -> EchoData {
        EchoData(
            weekColors: [
                ONETokens.oneRed, ONETokens.oneBlue, nil,
                ONETokens.oneGreen, ONETokens.moodYellow, ONETokens.moodPurple, nil
            ],
            dominantFeeling: .calm,
            repeatedSongs: [
                RepeatedSong(id: UUID(), songName: "Strobe", artistName: "deadmau5",
                             moodColorHex: "#5B8DEF", dates: ["Oca", "Mar", "Haz"], count: 3),
                RepeatedSong(id: UUID(), songName: "Last Last", artistName: "Burna Boy",
                             moodColorHex: "#E84040", dates: ["Şub", "Tem"], count: 2),
            ],
            silentDays: 12,
            silentDates: ["3 Şub", "7 Şub", "14 Şub", "1 Mar", "5 Mar",
                          "11 Mar", "20 Mar", "2 Nis", "8 Nis", "15 Nis", "22 Nis", "28 Nis"],
            longestStreak: StreakInfo(
                days: 14,
                startDate: "3 Oca",
                endDate: "16 Oca",
                colors: [
                    ONETokens.oneRed, ONETokens.moodOrange, ONETokens.moodYellow,
                    ONETokens.oneGreen, ONETokens.oneBlue, ONETokens.moodPurple,
                    ONETokens.oneRed, ONETokens.oneGreen, ONETokens.oneBlue,
                    ONETokens.moodOrange, ONETokens.moodYellow, ONETokens.moodPurple,
                    ONETokens.oneRed, ONETokens.oneBlue
                ]
            ),
            currentStreak: 5,
            hourDistribution: [
                7: 2, 8: 5, 9: 3, 10: 2, 12: 4, 13: 6, 14: 3,
                17: 2, 18: 4, 19: 8, 20: 12, 21: 9, 22: 6, 23: 3
            ],
            circleSyncMatches: [
                CircleSyncMatch(id: UUID(), date: Date(), dateLabel: "14 Mar",
                                songName: "Strobe", artistName: "deadmau5",
                                friendDisplayName: "Ayşe", moodColorHex: "#5B8DEF"),
                CircleSyncMatch(id: UUID(), date: Date(), dateLabel: "2 Mar",
                                songName: "Last Last", artistName: "Burna Boy",
                                friendDisplayName: "Mehmet", moodColorHex: "#E84040"),
            ],
            last30DaysColors: Array(repeating: ONETokens.oneBlue, count: 30)
        )
    }
}

struct RepeatedSong: Identifiable {
    let id: UUID
    let songName: String
    let artistName: String
    let moodColorHex: String
    let dates: [String]
    let count: Int
}

struct StreakInfo {
    let days: Int
    let startDate: String
    let endDate: String
    let colors: [Color]
}
