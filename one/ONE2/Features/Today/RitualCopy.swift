//
//  RitualCopy.swift
//  ONE 2.0
//
//  Ritüel kartlarının saf metin kararları.
//

import Foundation

nonisolated enum RitualCopy {

    static func title(_ flow: FlowKind) -> String {
        switch flow {
        case .moodCheckIn: return NSLocalizedString("one2.ritual.moodCheckIn.title", comment: "Flow title: mood check-in")
        case .daily:       return NSLocalizedString("one2.ritual.daily.title", comment: "Flow title: daily check-in")
        case .morning:     return NSLocalizedString("one2.ritual.morning.title", comment: "Flow title: morning preparation")
        case .evening:     return NSLocalizedString("one2.ritual.evening.title", comment: "Flow title: evening review")
        case .guided:      return NSLocalizedString("one2.ritual.guided.title", comment: "Flow title: guided journal")
        }
    }

    /// "Devam et · 3/6".
    static func resume(step: Int, total: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString("one2.ritual.continue", comment: "Resume flow at step x of y"), step, total)
    }

    static func focusSummary(_ focus: String) -> String {
        String(format: NSLocalizedString("one2.ritual.summary.focus", comment: "Morning summary: chosen focus"), focus)
    }

    static func practicesSummary(_ count: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString("one2.ritual.summary.practices", comment: "Evening summary: practices done"), count)
    }

    static func streak(_ count: Int) -> String {
        String.localizedStringWithFormat(NSLocalizedString("one2.today.streak", comment: "Streak pill, VoiceOver"), count)
    }

    static func backfillMessage(_ day: WeekDayViewData) -> String {
        String(format: NSLocalizedString("one2.backfill.body", comment: "Backfill sheet: <day> is open, you can fill it now"),
               day.relativeLabel)
    }
}
