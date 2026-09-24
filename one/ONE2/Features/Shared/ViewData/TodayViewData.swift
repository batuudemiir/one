//
//  TodayViewData.swift
//  ONE 2.0
//
//  Bugün ekranının view data'sı (06_giris_akislari.md › Bugün ekranı).
//  Saat kuralları (selamlama, kart sırası, kaçırılan sabah) burada saf.
//

import Foundation

// MARK: - Hafta şeridi

nonisolated enum WeekDayStatus: Hashable, Sendable {
    case done
    /// Sabah ya da akşamdan yalnız biri yapıldı.
    case half
    /// Geçmiş, kapanmamış gün.
    case gap
    /// Bugün, henüz kapanmadı.
    case today
    case future
}

nonisolated struct WeekDayViewData: Hashable, Sendable, Identifiable {
    /// `yyyy-MM-dd`.
    let id: String
    /// "Pzt".
    let weekdayLabel: String
    let dayNumber: Int
    let status: WeekDayStatus
    let isToday: Bool
    /// `gap` ve 7 gün içinde: dokununca doldurma sheet'i.
    let canBackfill: Bool
    /// VoiceOver ve sheet başlığı: "Salı, 22 Eylül".
    let longLabel: String
    /// Dünse "Dün", değilse gün adı (doldurma cümlesinde).
    let relativeLabel: String
}

// MARK: - Ritüel kartları

nonisolated enum RitualLayout: Hashable, Sendable {
    case daily, morningEvening
}

nonisolated struct MoodPillViewData: Hashable, Sendable {
    /// 1–5.
    let score: Int
    let label: String
    var emotions: [String] = []
}

nonisolated enum RitualCardState: Hashable, Sendable {
    case notStarted
    case inProgress(step: Int, total: Int)
    case done(echo: String, mood: MoodPillViewData?, summary: String?)
    /// Sabah kartı 14:00'ten sonra yapılmadıysa.
    case missed
}

nonisolated struct RitualCardViewData: Hashable, Sendable, Identifiable {
    let flow: FlowKind
    let title: String
    /// Mono "2 dk".
    let durationLabel: String
    let state: RitualCardState

    var id: String { flow.rawValue }
}

// MARK: - Pratikler ve tema

nonisolated struct PracticeTileViewData: Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let symbol: String
}

nonisolated struct WeeklyThemeViewData: Hashable, Sendable {
    let name: String
    /// 1–7.
    let dayIndex: Int
    let prompt: String
    /// Yazıldıysa ilk satır ("Devam et" + önizleme).
    var writtenFirstLine: String?
}

// MARK: - Ekran

nonisolated struct TodayViewData: Hashable, Sendable {
    /// `nil`: seri gizli (profil ayarı).
    var streak: Int?
    /// 0–23; selamlama ve kart sırası.
    var hour: Int
    var week: [WeekDayViewData]
    var layout: RitualLayout
    /// Günlük: [daily]. Sabah+akşam: [morning, evening] (sıra `TodayRules.ordered`).
    var rituals: [RitualCardViewData]
    var practices: [PracticeTileViewData]
    var theme: WeeklyThemeViewData?
    /// Üstte kapatılabilir tek satırlık not (eski Çevre bağlantısı).
    var notice: String?
}

nonisolated enum TodayViewState: Hashable, Sendable {
    case loading
    case loaded(TodayViewData)
}

// MARK: - Kurallar

nonisolated enum TodayRules {
    /// Selamlama: 05–12 günaydın, 12–18 iyi günler, 18–05 iyi akşamlar.
    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12:  return NSLocalizedString("one2.greeting.morning", comment: "Greeting 05-12")
        case 12..<18: return NSLocalizedString("one2.greeting.day", comment: "Greeting 12-18")
        default:      return NSLocalizedString("one2.greeting.evening", comment: "Greeting 18-05")
        }
    }

    /// Sabah+akşam: 05–14 sabah önde, sonrası akşam önde.
    static func ordered(_ cards: [RitualCardViewData], hour: Int) -> [RitualCardViewData] {
        let morningFirst = (5..<14).contains(hour)
        return cards.sorted { a, b in
            let rank = { (c: RitualCardViewData) -> Int in c.flow == .morning ? (morningFirst ? 0 : 1) : (morningFirst ? 1 : 0) }
            return rank(a) < rank(b)
        }
    }

    /// Sabah 14:00'ten sonra başlamadıysa kaçırıldı.
    static func morningState(_ state: RitualCardState, hour: Int) -> RitualCardState {
        state == .notStarted && hour >= 14 ? .missed : state
    }

    /// Geriye dönük doldurma penceresi (gün).
    static let backfillDays = 7
}
