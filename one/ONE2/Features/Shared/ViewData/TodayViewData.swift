//
//  TodayViewData.swift
//  ONE 2.0
//
//  Bugün ekranının parçaları: check-in özeti (E6 yankısı), pratikler,
//  haftalık tema (E5 + E4 günlük soru), seri (E8).
//

import Foundation

/// Bir check-in'in görünür özeti. `echo`: E6'nın tek cümlesi.
nonisolated struct CheckInSummary: Identifiable, Equatable, Sendable {
    let id: String
    let time: Date
    let slot: RitualSlot
    /// 1–5.
    let score: Int
    let emotions: [EmotionItem]
    let causes: [String]
    let echo: String?
}

/// Check-in kartı: yuva başına bir kart (sabah+akşam modunda iki).
nonisolated struct CheckInCardData: Identifiable, Equatable, Sendable {
    let slot: RitualSlot
    let summary: CheckInSummary?

    var id: RitualSlot { slot }
    var isDone: Bool { summary != nil }
}

/// "Pratiklerin" ızgarasındaki kısayol.
nonisolated struct PracticeTileData: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let icon: ONE2Icon
    /// Açılacak içerik (rehberli günlük, ritüel şablonu).
    let contentID: String
}

/// Haftalık tema kartı. `day`: 1…7; `unlockedDays`: bugüne dek açılanlar.
nonisolated struct ThemeCardData: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let day: Int
    let unlockedDays: Int
    let promptID: String
    let question: String
    let isWritten: Bool
    /// Yazıldıysa ilk satır ("Devam et" önizlemesi).
    let firstLine: String?
}

/// Seri (E8). Gizliyken motor saymaya devam eder; kart gösterilmez.
nonisolated struct StreakData: Equatable, Sendable {
    let current: Int
    let longest: Int
    let isVisible: Bool
    /// Bugün henüz tamamlanmadı; seri dünden sayılıyor.
    let isAtRisk: Bool
}

/// Bugün ekranının tamamı.
nonisolated struct TodayData: Equatable, Sendable {
    let week: WeekStripData
    let streak: StreakData
    let checkIns: [CheckInCardData]
    let practices: [PracticeTileData]
    let theme: ThemeCardData?
}
