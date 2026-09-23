//
//  DayKey.swift
//  ONE 2.0
//
//  Bir kaydın ait olduğu *yerel* gün: `yyyy-MM-dd` (02_veri_modeli.md, ilke 1).
//
//  Gün, kaydın yazıldığı andaki takvimden bir kez türetilir ve bir daha
//  hesaplanmaz; kullanıcı saat dilimi değiştirse de kayıt gününden kaymaz.
//  Gün aritmetiği (`adding(days:)`) saat diliminden bağımsız yapılır: sabit
//  UTC Gregoryen takvim üzerinde yalnız yıl/ay/gün. DST geçişleri ve saat
//  dilimi farkları sonucu etkilemez.
//

import Foundation

nonisolated struct DayKey: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init?(year: Int, month: Int, day: Int) {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        // Geçersiz tarihleri (31 Şubat) reddet: takvim normalize ederse eşleşmez.
        guard let date = Self.arithmetic.date(from: comps) else { return nil }
        let back = Self.arithmetic.dateComponents([.year, .month, .day], from: date)
        guard back.year == year, back.month == month, back.day == day else { return nil }
        self.year = year; self.month = month; self.day = day
    }

    /// `date` anının `calendar`'ın saat dilimindeki günü.
    init(date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year ?? 1970
        self.month = c.month ?? 1
        self.day = c.day ?? 1
    }

    /// `yyyy-MM-dd` metninden.
    init?(_ string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    /// v3 `DailySong.date` gibi, yazan cihazın saat diliminde gece yarısına
    /// normalize edilmiş bir tarihten gün türetir.
    ///
    /// Saat dilimi saklanmadığı için tarih şimdiki takvimde okunur ve **en
    /// yakın gece yarısına** yuvarlanır (+12 saat, sonra günü al). Yazma ve
    /// okuma saat dilimleri arasındaki fark 12 saatten azsa doğru günü verir.
    /// Daha büyük farkta bir gün kayma kabul edilir (MIGRATION.md §1.2, R4).
    init(normalizedMidnight date: Date, calendar: Calendar) {
        self.init(date: date.addingTimeInterval(12 * 3600), calendar: calendar)
    }

    var string: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    var description: String { string }

    func adding(days: Int) -> DayKey {
        guard days != 0,
              let start = Self.arithmetic.date(from: components),
              let moved = Self.arithmetic.date(byAdding: .day, value: days, to: start) else { return self }
        return DayKey(date: moved, calendar: Self.arithmetic)
    }

    /// `self`'ten `other`'a kaç gün var (other sonraysa pozitif).
    func days(to other: DayKey) -> Int {
        guard let a = Self.arithmetic.date(from: components),
              let b = Self.arithmetic.date(from: other.components) else { return 0 }
        return Self.arithmetic.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// Bu günün `calendar`'daki başlangıç anı (sorgu aralıkları için).
    func startDate(in calendar: Calendar) -> Date? {
        calendar.date(from: components)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: - Codable: tek string olarak

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Invalid dayKey: \(raw)"))
        }
        self = key
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(string)
    }

    // MARK: - Private

    private var components: DateComponents {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return c
    }

    /// Yalnız gün aritmetiği için: saat dilimi ve DST'den bağımsız.
    private static let arithmetic: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
}
