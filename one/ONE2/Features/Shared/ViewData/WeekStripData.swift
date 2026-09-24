//
//  WeekStripData.swift
//  ONE 2.0
//
//  Hafta şeridi (components/WeekStrip.md). Hafta ISO 8601, pazartesi
//  başlar (E5). Tamamlanma E8'den gelir: yarım gün (sabah+akşam modunda
//  birinden biri) seriye yeter. Geriye dönük doldurma son 7 gün.
//

import Foundation

nonisolated struct WeekDayState: Identifiable, Equatable, Sendable {
    enum Completion: Equatable, Sendable { case none, half, done }
    enum Position: Equatable, Sendable { case past, today, future }
    /// Hücrenin çizimi: done/half/gap/today/future.
    enum Kind: Equatable, Sendable { case done, half, gap, today, future }

    let day: DayKey
    /// ISO gün numarası: 1 = pazartesi … 7 = pazar.
    let weekday: Int
    let completion: Completion
    let position: Position

    var id: DayKey { day }

    var kind: Kind {
        switch position {
        case .today:  return .today
        case .future: return .future
        case .past:
            switch completion {
            case .done: return .done
            case .half: return .half
            case .none: return .gap
            }
        }
    }
}

nonisolated struct WeekStripData: Equatable, Sendable {
    /// Geriye dönük doldurma penceresi (E8, karar 1).
    static let backfillWindow = 7

    let days: [WeekDayState]
    let today: DayKey

    /// Boş kalmış geçmiş gün son 7 gün içindeyse doldurulabilir.
    func canBackfill(_ day: WeekDayState) -> Bool {
        guard day.kind == .gap else { return false }
        let distance = day.day.days(to: today)
        return distance >= 1 && distance <= Self.backfillWindow
    }

    /// `day`'in haftası (pazartesi–pazar); tamamlanma bilinmeyen gün `none`.
    static func week(containing day: DayKey, today: DayKey, completions: [DayKey: WeekDayState.Completion]) -> WeekStripData {
        let monday = day.adding(days: 1 - isoWeekday(day))
        let days = (0..<7).map { offset -> WeekDayState in
            let d = monday.adding(days: offset)
            let position: WeekDayState.Position = d < today ? .past : (d == today ? .today : .future)
            return WeekDayState(day: d, weekday: offset + 1, completion: completions[d] ?? .none, position: position)
        }
        return WeekStripData(days: days, today: today)
    }

    /// ISO gün numarası (1 = pazartesi). Gün aritmetiği saat diliminden bağımsız.
    static func isoWeekday(_ day: DayKey) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let date = day.startDate(in: cal) else { return 1 }
        let sundayFirst = cal.component(.weekday, from: date) // 1 = pazar
        return (sundayFirst + 5) % 7 + 1
    }
}
