//
//  SeededRandom.swift
//  ONE 2.0
//
//  Motorların tek rastgelelik kaynağı (04_arka_plan_motorlari.md › Ortak
//  ilkeler). Aynı tohum her cihazda, her açılışta aynı diziyi verir: günün
//  sözü iki cihazda aynı çıkar, testler tekrarlanabilir.
//
//  Tohum metinden FNV-1a 64 ile türetilir (Swift'in `Hasher`'ı süreç başına
//  rastgele tuzlandığı için kullanılamaz). Üreteç SplitMix64.
//

import Foundation

nonisolated struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// Parçalar `|` ile birleştirilip tohumlanır:
    /// `SeededRandom("quote.daily", salt.uuidString, day.string)`.
    init(_ parts: String...) {
        self.init(seed: Self.fnv1a(parts.joined(separator: "|")))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// [0, 1) aralığında sayı.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// Ağırlıklı seçim; ağırlıklar ≤ 0 ise eşit. Boş dizide `nil`.
    mutating func weightedIndex(_ weights: [Double]) -> Int? {
        guard !weights.isEmpty else { return nil }
        let positive = weights.map { max(0, $0) }
        let total = positive.reduce(0, +)
        guard total > 0 else { return Int(next() % UInt64(weights.count)) }
        var target = unit() * total
        for (i, w) in positive.enumerated() {
            target -= w
            if target < 0 { return i }
        }
        return positive.lastIndex { $0 > 0 }
    }

    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
