//
//  Streak.swift
//  ONE 2.0
//
//  Gün tamamlanma ve seri (04_arka_plan_motorlari.md › E8). Saklanmaz, her
//  seferinde `DayRecord`'lardan türetilir.
//
//  - Günlük mod: günlük kart tamamsa gün tam.
//  - Sabah-akşam modu: ikisinden biri = yarım gün, ikisi = tam gün. Seri için
//    yarım gün yeterli.
//  - Alternatif tamamlama: o gün ≥ 20 kelimelik yazılı girdi günü tamam sayar
//    (ritüeli atlayıp yazan cezalandırılmaz).
//  - Geriye dönük doldurma: son 7 gün; doldurulan gün seriyi onarır.
//  - Seri: bugünden geriye kesintisiz tamam günler. Bugün henüz tamam
//    değilse seri dünden sayılır ve "risk altında" durumu verilir.
//  - Seri görünürlüğü kapatılabilir; hesap sürer (rozetler için).
//  - v3 günleri (`DailySong`) bu hesaba hiç girmez (ADR-001, B').
//

import Foundation

/// Kullanıcının seçtiği günlük ritüel düzeni.
nonisolated enum RitualMode: String, Codable, Sendable, CaseIterable {
    /// Günde tek kart (günlük check-in).
    case daily
    /// Sabah hazırlığı + akşam refleksiyonu.
    case morningEvening
}

/// Günü neyin tamamladığı (`DayRecord.completedBy`).
nonisolated enum DayCompletionSource: String, Codable, Sendable {
    case ritual, writing
}

/// Hafta şeridindeki gün durumu.
nonisolated enum DayStatus: Sendable, Equatable {
    case none, half, full
}

/// Bir günün tamamlanma durumu: `DayRecord`'un değer karşılığı.
nonisolated struct DayCompletion: Hashable, Sendable {
    let day: DayKey
    var dailyCompletedAt: Date?
    var morningCompletedAt: Date?
    var eveningCompletedAt: Date?
    var completedBy: DayCompletionSource?

    init(day: DayKey,
         dailyCompletedAt: Date? = nil,
         morningCompletedAt: Date? = nil,
         eveningCompletedAt: Date? = nil,
         completedBy: DayCompletionSource? = nil) {
        self.day = day
        self.dailyCompletedAt = dailyCompletedAt
        self.morningCompletedAt = morningCompletedAt
        self.eveningCompletedAt = eveningCompletedAt
        self.completedBy = completedBy
    }

    func status(in mode: RitualMode) -> DayStatus {
        switch mode {
        case .daily:
            if dailyCompletedAt != nil { return .full }
        case .morningEvening:
            if morningCompletedAt != nil && eveningCompletedAt != nil { return .full }
            if morningCompletedAt != nil || eveningCompletedAt != nil {
                return completedBy == .writing ? .full : .half
            }
        }
        return completedBy == .writing ? .full : .none
    }

    /// Seri için: yarım gün de sayılır.
    func isComplete(in mode: RitualMode) -> Bool {
        status(in: mode) != .none
    }

    var hasBothRituals: Bool { morningCompletedAt != nil && eveningCompletedAt != nil }
}

/// E8 sabitleri.
nonisolated enum DayCompletionRules {
    /// Geriye dönük doldurulabilen gün sayısı (dün dahil, bugün hariç).
    static let backfillDays = 7
    /// Yazılı girdinin günü tamamlaması için en az kelime.
    static let writingWordThreshold = 20

    static func canBackfill(_ day: DayKey, today: DayKey) -> Bool {
        day < today && day.days(to: today) <= backfillDays
    }

    /// Ritüel olmayan yazılı girdiler (soru, söz, boş sayfa, rehberli, şablon).
    static func countsAsWriting(_ kind: EntryKind, words: Int) -> Bool {
        let writingKinds: Set<EntryKind> = [.freeform, .prompt, .guided, .template, .quoteReflection]
        return writingKinds.contains(kind) && words >= writingWordThreshold
    }
}

nonisolated struct StreakState: Equatable, Sendable {
    let count: Int
    /// Bugün henüz tamam değil ve seri > 0: akşam hatırlatması için.
    let atRisk: Bool
    let isVisible: Bool
    let longest: Int
}

nonisolated enum Streak {

    /// Güncel seri. `completed`: tamam sayılan günler.
    static func current(completed: Set<DayKey>, today: DayKey) -> Int {
        var cursor = completed.contains(today) ? today : today.adding(days: -1)
        var count = 0
        while completed.contains(cursor) {
            count += 1
            cursor = cursor.adding(days: -1)
        }
        return count
    }

    static func current(_ days: [DayCompletion], mode: RitualMode, today: DayKey) -> Int {
        current(completed: completedDays(days, mode: mode), today: today)
    }

    /// Tüm zamanların en uzun serisi.
    static func longest(completed: Set<DayKey>) -> Int {
        var best = 0
        for day in completed where !completed.contains(day.adding(days: -1)) {
            var length = 1
            var next = day.adding(days: 1)
            while completed.contains(next) {
                length += 1
                next = next.adding(days: 1)
            }
            best = max(best, length)
        }
        return best
    }

    static func state(_ days: [DayCompletion], mode: RitualMode, today: DayKey, visible: Bool = true) -> StreakState {
        let completed = completedDays(days, mode: mode)
        let count = current(completed: completed, today: today)
        return StreakState(count: count, atRisk: count > 0 && !completed.contains(today),
                           isVisible: visible, longest: longest(completed: completed))
    }

    static func completedDays(_ days: [DayCompletion], mode: RitualMode) -> Set<DayKey> {
        Set(days.lazy.filter { $0.isComplete(in: mode) }.map(\.day))
    }
}
