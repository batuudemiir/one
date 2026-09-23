//
//  Streak.swift
//  ONE 2.0
//
//  Seri hesabı (02_veri_modeli.md, DayRecord). Saklanmaz, her seferinde
//  `DayRecord`'lardan türetilir.
//
//  Kurallar (taslak; pencere ve iki parçalı modun kuralı teardown'da
//  doğrulanacak):
//  - Bir gün, seçili ritüel modunun gerektirdiği kart(lar) tamamlandıysa
//    "tamam" sayılır. Geriye dönük doldurma da günü tamam yapar.
//  - Güncel seri, bugünden geriye kesintisiz tamam günlerin sayısıdır.
//    Bugün henüz tamamlanmadıysa seri dünden sayılır: gün bitmeden seri
//    kırılmış sayılmaz.
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

/// Bir günün tamamlanma durumu: `DayRecord`'un değer karşılığı.
nonisolated struct DayCompletion: Hashable, Sendable {
    let day: DayKey
    var dailyCompletedAt: Date?
    var morningCompletedAt: Date?
    var eveningCompletedAt: Date?

    init(day: DayKey,
         dailyCompletedAt: Date? = nil,
         morningCompletedAt: Date? = nil,
         eveningCompletedAt: Date? = nil) {
        self.day = day
        self.dailyCompletedAt = dailyCompletedAt
        self.morningCompletedAt = morningCompletedAt
        self.eveningCompletedAt = eveningCompletedAt
    }

    /// İki parçalı modda her iki kart gerekli (tahmin; teardown doğrulayacak).
    func isComplete(in mode: RitualMode) -> Bool {
        switch mode {
        case .daily:
            return dailyCompletedAt != nil
        case .morningEvening:
            return morningCompletedAt != nil && eveningCompletedAt != nil
        }
    }
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

    static func completedDays(_ days: [DayCompletion], mode: RitualMode) -> Set<DayKey> {
        Set(days.lazy.filter { $0.isComplete(in: mode) }.map(\.day))
    }
}
