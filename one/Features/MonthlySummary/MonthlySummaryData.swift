//
//  MonthlySummaryData.swift
//  one
//
//  Aylık özet ekranı için veri modeli.
//

import SwiftUI

// MARK: - TrackEntry
struct TrackEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let artist: String
    let days: Int
    let gradientColors: [Color]
    let emoji: String
}

// MARK: - MonthlySummaryData
struct MonthlySummaryData {
    let month: String                              // "Şubat"
    let year: Int                                  // 2026
    let totalDays: Int                             // 28
    let uniqueArtists: Int                         // 12
    let maxRepeat: Int                             // 4
    let dominantMood: String                       // "Enerjik"
    let dominantMoodColor: Color
    let dailyMoods: [Color]                        // 28 element
    let emotionBreakdown: [(name: String, percentage: Double, color: Color)]
    let topTracks: [TrackEntry]
    let totalEntries: Int                          // Tüm DailySong kayıtları (multi-entry dahil)
    let daysLogged: Int                            // Giriş yapılan benzersiz gün sayısı
    let monthStreak: Int                           // Ay içindeki en uzun ardışık gün serisi
    let storyTitle: String                         // Hikayeleştirilmiş başlık
    let storySubtitle: String                      // Hikayeleştirilmiş alt metin
}

// MARK: - Mock Data
extension MonthlySummaryData {
    static var mock: MonthlySummaryData {
        let orange  = ONETokens.moodAmber           // #C97840
        let red     = ONETokens.summaryMockRed      // #C94040
        let yellow  = ONETokens.summaryMockYellow   // #C9A840
        let teal    = ONETokens.summaryMockTeal     // #40A89C
        let blue    = ONETokens.summaryMockBlue     // #4070C9
        let purple  = ONETokens.summaryMockPurple   // #7840C9

        let moodPattern: [Color] = [
            orange, orange, yellow, teal,   blue,   orange,
            red,    orange, orange, yellow, orange, blue,
            teal,   purple, orange, orange, red,    orange,
            orange, yellow, blue,   orange, teal,   orange,
            orange, red,    yellow, orange
        ]

        return MonthlySummaryData(
            month: "Şubat",
            year: 2026,
            totalDays: 28,
            uniqueArtists: 12,
            maxRepeat: 4,
            dominantMood: "Enerjik",
            dominantMoodColor: orange,
            dailyMoods: moodPattern,
            emotionBreakdown: [
                (name: "Enerjik",  percentage: 0.46, color: orange),
                (name: "Nostaljik",percentage: 0.25, color: blue),
                (name: "Sakin",    percentage: 0.18, color: teal),
                (name: "Melankolik",percentage: 0.11, color: purple)
            ],
            topTracks: [
                TrackEntry(rank: 1, name: "Neredesin Sen", artist: "Fazıl Say",
                           days: 6, gradientColors: [orange, yellow], emoji: "🎹"),
                TrackEntry(rank: 2, name: "Huzur", artist: "Jakuzi",
                           days: 5, gradientColors: [blue, teal], emoji: "🌊"),
                TrackEntry(rank: 3, name: "Gece Yarısı", artist: "Ceza",
                           days: 4, gradientColors: [purple, red], emoji: "🌙"),
                TrackEntry(rank: 4, name: "Elveda", artist: "Teoman",
                           days: 3, gradientColors: [red, orange], emoji: "🔥"),
                TrackEntry(rank: 5, name: "Yüksek Sadakat", artist: "Yüksek Sadakat",
                           days: 2, gradientColors: [teal, blue], emoji: "⚡️")
            ],
            totalEntries: 28,
            daysLogged:   22,
            monthStreak:  9,
            storyTitle: "Enerjik Müziklerin Ayı",
            storySubtitle: "En çok akşam 20:00'de düşüncelere daldın."
        )
    }
}
