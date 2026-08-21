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

struct MoodStat: Identifiable {
    let id = UUID()
    let label: String
    let colorHex: String
    let count: Int
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

    // MARK: — Ek istatistikler
    let totalSongs: Int
    let thisMonthSongs: Int
    let mostActiveDayOfWeek: String?    // "Pazartesi" gibi
    let averageSongsPerMonth: Double
    let moodDistribution: [MoodStat]          // tüm zamanlar
    let thisMonthMoodDistribution: [MoodStat] // bu ay

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
        last30DaysColors: Array(repeating: nil, count: 30),
        totalSongs: 0,
        thisMonthSongs: 0,
        mostActiveDayOfWeek: nil,
        averageSongsPerMonth: 0,
        moodDistribution: [],
        thisMonthMoodDistribution: []
    )

    static func mock() -> EchoData {
        EchoData(
            weekColors: [
                ONEBrand.kor, V3Tokens.info, nil,
                V3Tokens.success, V3Mood.mutlu.color, V3Mood.gergin.color, nil
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
                    ONEBrand.kor, V3Mood.coskulu.color, V3Mood.mutlu.color,
                    V3Tokens.success, V3Tokens.info, V3Mood.gergin.color,
                    ONEBrand.kor, V3Tokens.success, V3Tokens.info,
                    V3Mood.coskulu.color, V3Mood.mutlu.color, V3Mood.gergin.color,
                    ONEBrand.kor, V3Tokens.info
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
            last30DaysColors: Array(repeating: V3Tokens.info, count: 30),
            totalSongs: 47,
            thisMonthSongs: 12,
            mostActiveDayOfWeek: "Salı",
            averageSongsPerMonth: 15.3,
            moodDistribution: [
                MoodStat(label: "Sakin", colorHex: "#3BBFCF", count: 12),
                MoodStat(label: "Enerjik", colorHex: "#FF8C42", count: 9),
                MoodStat(label: "Derin", colorHex: "#5560B8", count: 8),
                MoodStat(label: "Taze", colorHex: "#7CC874", count: 7),
            ],
            thisMonthMoodDistribution: [
                MoodStat(label: "Sakin", colorHex: "#3BBFCF", count: 5),
                MoodStat(label: "Enerjik", colorHex: "#FF8C42", count: 4),
                MoodStat(label: "Derin", colorHex: "#5560B8", count: 3),
            ]
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
