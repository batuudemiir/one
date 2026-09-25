//
//  WeekStripModel.swift
//  ONE 2.0
//
//  Hafta şeridinin verisi (WeekStrip.md): pazartesiden pazara 7 gün, her
//  günün tamamlanma durumu. Bugün ekranı ve kapanış (Seal) aynı şeridi
//  gösterir. Saf: gün tamamlanmaları + mod → hücreler.
//

import Foundation

nonisolated enum WeekCellState: Hashable, Sendable {
    /// Gün kapandı (ritüel ya da ≥ 20 kelimelik yazı).
    case done
    /// Sabah+akşam modunda iki ritüelden biri.
    case half
    /// Geçmiş ya da bugün, henüz kapanmadı.
    case open
    /// Gelecek gün; dokunulamaz.
    case future
}

nonisolated struct WeekDayCell: Hashable, Sendable, Identifiable {
    let day: DayKey
    let state: WeekCellState
    let isToday: Bool

    var id: String { day.string }
}

nonisolated enum WeekStripModel {

    /// `today`'in haftası (ISO: pazartesi başlar).
    static func week(containing today: DayKey, completions: [DayCompletion], mode: RitualMode) -> [WeekDayCell] {
        let monday = today.adding(days: 1 - today.isoWeekday)
        let byDay = Dictionary(completions.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })
        return (0..<7).map { offset in
            let day = monday.adding(days: offset)
            let state: WeekCellState
            if day > today {
                state = .future
            } else {
                switch byDay[day]?.status(in: mode) ?? .none {
                case .full: state = .done
                case .half: state = .half
                case .none: state = .open
                }
            }
            return WeekDayCell(day: day, state: state, isToday: day == today)
        }
    }

    /// Takvimin kısa gün adı için sembol dizini (`Calendar.shortStandaloneWeekdaySymbols`,
    /// 0 = pazar).
    static func symbolIndex(for day: DayKey) -> Int {
        day.isoWeekday % 7
    }
}
