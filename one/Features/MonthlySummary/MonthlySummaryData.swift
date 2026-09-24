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
    let storyTitle: String                         // Hikayeleştirilmiş başlık
    let storySubtitle: String                      // Hikayeleştirilmiş alt metin
}

// MARK: - Mock Data
extension MonthlySummaryData {
    static var mock: MonthlySummaryData {
        // Önizleme paleti. Sahte **veri**, ama sahte **renk** değil: altı
        // ham hex duruyordu (#C97840, #C94040, …) ve ONE'ın dokuz mood
        // renginin hiçbiri değildi. Önizleme, ürünün asla çizmediği bir
        // paleti gösteriyordu — yani tasarımı önizlemeden değerlendiren
        // herkes yanlış rengi görüyordu.
        let orange  = V3Mood.coskulu.color
        let red     = V3Mood.atesli.color
        let yellow  = V3Mood.mutlu.color
        let teal    = V3Mood.huzurlu.color
        let blue    = V3Mood.odakli.color
        let purple  = V3Mood.gergin.color

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
                           days: 6, emoji: "🎹"),
                TrackEntry(rank: 2, name: "Huzur", artist: "Jakuzi",
                           days: 5, emoji: "🌊"),
                TrackEntry(rank: 3, name: "Gece Yarısı", artist: "Ceza",
                           days: 4, emoji: "🌙"),
                TrackEntry(rank: 4, name: "Elveda", artist: "Teoman",
                           days: 3, emoji: "🔥"),
                TrackEntry(rank: 5, name: "Yüksek Sadakat", artist: "Yüksek Sadakat",
                           days: 2, emoji: "⚡️")
            ],
            totalEntries: 28,
            daysLogged:   22,
            storyTitle: "Enerjik Müziklerin Ayı",
            storySubtitle: "En çok akşam 20:00'de düşüncelere daldın."
        )
    }
}
