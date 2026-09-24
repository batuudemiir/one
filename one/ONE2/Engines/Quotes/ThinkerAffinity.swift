//
//  ThinkerAffinity.swift
//  ONE 2.0
//
//  Düşünür yakınlığı ve yeniliği (08 §4.5, §4.3). `ContentExposure`
//  kayıtlarından hesaplanır; ayrı entity yok.
//
//  Olay puanları: beğeni +1 · yazma +3 · paylaşım +2 · uzun bakış +0,5 ·
//  hızlı geçiş −0,3. Kayıt olay başına sayı + son olay zamanı tuttuğu için
//  azalma son olay zamanına göre uygulanır (yarı ömür 30 gün). Beğeniyi geri
//  almak beğeni puanını siler (+1 −1 = 0). Skor [−3, +10] aralığında.
//

import Foundation

nonisolated struct ThinkerSignals: Sendable {
    /// Ham yakınlık, [−3, +10].
    var affinity: [ThinkerID: Double] = [:]
    /// Düşünürün herhangi bir sözünün son görülmesi.
    var lastSeen: [ThinkerID: Date] = [:]

    static let empty = ThinkerSignals()

    static let minScore = -3.0
    static let maxScore = 10.0
    /// Bu skorun altındaki düşünür "Sana özel"de yalnız keşif payına girer.
    static let mutedAt = -2.0
    static let halfLife: TimeInterval = 30 * 86_400
    static let noveltyWindow: TimeInterval = 7 * 86_400

    enum Points {
        static let like = 1.0
        static let write = 3.0
        static let share = 2.0
        static let longLook = 0.5
        static let skip = -0.3
    }

    static func from(_ exposure: ExposureSnapshot, catalog: ContentCatalog, now: Date) -> ThinkerSignals {
        var raw: [ThinkerID: Double] = [:]
        var seen: [ThinkerID: Date] = [:]
        for r in exposure.records.values {
            guard let id = catalog.quote(r.contentID)?.authorID else { continue }
            var s = 0.0
            if r.liked { s += Points.like * decay(r.likedAt, now) }
            s += Double(r.writtenCount) * Points.write * decay(r.lastWrittenAt, now)
            s += Double(r.shareCount) * Points.share * decay(r.lastSharedAt, now)
            s += Double(r.longLookCount) * Points.longLook * decay(r.lastLongLookAt, now)
            s += Double(r.skipCount) * Points.skip * decay(r.lastSkippedAt, now)
            if s != 0 { raw[id, default: 0] += s }
            if let at = r.lastSeenAt, r.wasSeen { seen[id] = max(seen[id] ?? at, at) }
        }
        return ThinkerSignals(affinity: raw.mapValues { min(maxScore, max(minScore, $0)) }, lastSeen: seen)
    }

    static func decay(_ at: Date?, _ now: Date) -> Double {
        guard let at else { return 1 }
        return pow(0.5, max(0, now.timeIntervalSince(at)) / halfLife)
    }

    func score(_ id: ThinkerID?) -> Double { id.flatMap { affinity[$0] } ?? 0 }

    /// Puanlama için 0–1: −3 → 0, +10 → 1.
    func scaled(_ id: ThinkerID?) -> Double {
        (score(id) - Self.minScore) / (Self.maxScore - Self.minScore)
    }

    func isMuted(_ id: ThinkerID?) -> Bool { score(id) <= Self.mutedAt }

    func wasSeen(_ id: ThinkerID?) -> Bool { id.map { lastSeen[$0] != nil } ?? false }

    /// Hiç gösterilmediyse 1, son 7 günde gösterildiyse 0, arası 0,5.
    func novelty(_ id: ThinkerID?, now: Date) -> Double {
        guard let id, let at = lastSeen[id] else { return 1 }
        return now.timeIntervalSince(at) < Self.noveltyWindow ? 0 : 0.5
    }
}
