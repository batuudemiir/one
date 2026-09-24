//
//  WeekStripAdapter.swift
//  ONE 2.0
//
//  Canlı gün kayıtlarının hücrelerini (`WeekDayCell`) şeridin view
//  data'sına çevirir. Kapanış (Seal) ve motora bağlı Bugün bunu kullanır.
//

import Foundation

nonisolated enum WeekStripAdapter {

    static func viewData(_ cells: [WeekDayCell], calendar: Calendar = .current) -> [WeekDayViewData] {
        let today = cells.first(where: \.isToday)?.day ?? cells.last?.day
        return cells.map { cell in
            let status: WeekDayStatus
            switch cell.state {
            case .done:   status = .done
            case .half:   status = .half
            case .future: status = .future
            case .open:   status = cell.isToday ? .today : .gap
            }
            let age = today.map { cell.day.days(to: $0) } ?? 0
            let date = cell.day.startDate(in: calendar)
            let weekday = date?.formatted(.dateTime.weekday(.wide)) ?? cell.day.string
            return WeekDayViewData(
                id: cell.day.string,
                weekdayLabel: calendar.shortStandaloneWeekdaySymbols[WeekStripModel.symbolIndex(for: cell.day)],
                dayNumber: cell.day.day,
                status: status,
                isToday: cell.isToday,
                canBackfill: status == .gap && age >= 1 && age <= TodayRules.backfillDays,
                longLabel: date?.formatted(.dateTime.weekday(.wide).day().month(.wide)) ?? cell.day.string,
                relativeLabel: age == 1 ? NSLocalizedString("one2.day.yesterday", comment: "Yesterday, capitalised") : weekday
            )
        }
    }
}
