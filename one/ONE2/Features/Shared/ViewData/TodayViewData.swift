//
//  TodayViewData.swift
//  ONE 2.0
//
//  Bugün ekranının parçaları (07 §5.1): ritüel kartları, pratikler,
//  haftalık tema (E5 + E4 günlük soru), seri (E8), geri dönüş kartı (§5.11).
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

/// Ritüel modu (Profil › Günlük akış).
nonisolated enum RitualModeData: String, Hashable, Sendable {
    /// Günde bir kez: tek kart, Akış 2.
    case daily
    /// Sabah ve akşam: iki kart, Akış 3 ve 4.
    case morningEvening
}

/// Ritüel kartının durumu (07 §5.1).
nonisolated enum RitualStatus: Equatable, Sendable {
    /// Başlık + mono süre + `Başla`.
    case notStarted
    /// "Devam et · n/m" + ilerleme çizgisi; `step` 1'den.
    case inProgress(step: Int, total: Int)
    /// Yankı + MoodPill + tek satır özet (sabah → odak, akşam → "4/5 pratik").
    case done(CheckInSummary, detail: String?)
    /// Sabah 14:00 sonrası yapılmadı: sönük + "Yine de yap".
    case missed
    /// Geçmiş günde kayıt yok ve doldurma penceresi dışında.
    case empty
}

/// Ritüel kartı: yuva başına bir kart (sabah+akşam modunda iki).
nonisolated struct CheckInCardData: Identifiable, Equatable, Sendable {
    let slot: RitualSlot
    let flow: FlowKind
    let status: RitualStatus
    /// Mono süre ("2 dk").
    let minutes: Int

    var id: RitualSlot { slot }

    var summary: CheckInSummary? {
        if case .done(let summary, _) = status { return summary }
        return nil
    }
}

/// "Pratiklerin" ızgarasındaki kısayol. Dokunma bugün için işaretler.
nonisolated struct PracticeTileData: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let icon: ONE2Icon
    /// Açılacak içerik (rehberli günlük, ritüel şablonu).
    let contentID: String
    let isDoneToday: Bool
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

/// Seri (E8). Gizliyken motor saymaya devam eder; hap gösterilmez.
nonisolated struct StreakData: Equatable, Sendable {
    let current: Int
    let longest: Int
    let isVisible: Bool
    /// Bugün henüz tamamlanmadı; seri dünden sayılıyor.
    let isAtRisk: Bool
}

/// Bugün ekranının bir günü.
nonisolated struct TodayData: Equatable, Sendable {
    /// Selamlamanın ikinci satırı ve profil yuvarlağının baş harfi.
    let userName: String?
    let mode: RitualModeData
    /// İlk gün: seri hapı yok, hafta şeridinde yalnız bugün.
    let isFirstDay: Bool
    let streak: StreakData
    let resurface: ResurfaceCardData?
    let checkIns: [CheckInCardData]
    let practices: [PracticeTileData]
    let theme: ThemeCardData?
}

extension FlowKind {
    /// Akışın ve ritüel kartının başlığı.
    var title: String {
        switch self {
        case .moodCheckIn:  return one2String("one2.flow.moodCheckIn")
        case .dailyCheckIn: return one2String("one2.flow.dailyCheckIn")
        case .morning:      return one2String("one2.flow.morning")
        case .evening:      return one2String("one2.flow.evening")
        }
    }
}
