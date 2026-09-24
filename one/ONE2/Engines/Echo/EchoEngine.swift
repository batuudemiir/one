//
//  EchoEngine.swift
//  ONE 2.0
//
//  Check-in yankı motoru (04_arka_plan_motorlari.md › E6): check-in sonrası
//  Bugün kartındaki tek yargısız cümle.
//
//  - Koşulu sağlayan yankılar içinde ağırlıklı rastgele; koşullu öğe yoksa
//    genel havuz. Bir yankının her belirttiği koşul sağlanmalı.
//  - 14 gün içinde gösterilen yankı tekrar etmez.
//  - Ton (yargı, "neşelen", ünlem, emoji, sonuç vaadi yok) içerikte ve
//    doğrulayıcıda (E18) denetlenir; motor ayrıca düşük skorda skoru
//    kapsamayan yankıyı hiç seçmez.
//

import Foundation

nonisolated struct EchoInput: Sendable {
    /// 1–5.
    var score: Int
    var emotionIDs: [String] = []
    var causeIDs: [String] = []
    var dayPart: DayPart = .any
    var isFirstCheckin = false
    /// Son 7 günün gün başına ortalama skorları, eskiden yeniye (bugün dahil değil).
    var recentDailyScores: [Double] = []
    /// Tohum parçası: check-in kimliği (aynı check-in → aynı yankı).
    var checkInID: String = ""
}

nonisolated enum EchoSelection {
    static let repeatWindow: TimeInterval = 14 * 86_400

    /// Son 7 günün eğilimi; en az 3 gün veri gerekir. İlk yarı ile son yarının
    /// ortalaması arasındaki fark ≥ 0,75 → yukarı/aşağı, değilse düz.
    static func trend(_ scores: [Double]) -> MoodTrend? {
        guard scores.count >= 3 else { return nil }
        let half = scores.count / 2
        let first = scores.prefix(half), last = scores.suffix(scores.count - half)
        let delta = last.reduce(0, +) / Double(last.count) - first.reduce(0, +) / Double(first.count)
        if delta >= 0.75 { return .up }
        if delta <= -0.75 { return .down }
        return .flat
    }

    static func matches(_ c: Echo.Conditions, input: EchoInput, families: Set<String>, trend: MoodTrend?) -> Bool {
        if let scores = c.scoreIn, !scores.contains(input.score) { return false }
        if let fams = c.emotionFamilyAny, families.isDisjoint(with: fams) { return false }
        if let causes = c.causeAny, Set(input.causeIDs).isDisjoint(with: causes) { return false }
        if let part = c.timeOfDay, part != .any, part != input.dayPart { return false }
        if let t = c.trend, t != trend { return false }
        if let first = c.firstCheckin, first != input.isFirstCheckin { return false }
        return true
    }

    static func choose(_ echoes: [Echo], input: EchoInput, catalog: ContentCatalog, exposure: ExposureSnapshot,
                       now: Date, lang: String, rng: inout SeededRandom) -> Echo? {
        let families = Set(input.emotionIDs.compactMap(catalog.emotionFamily))
        let trend = trend(input.recentDailyScores)
        let cutoff = now.addingTimeInterval(-repeatWindow)
        let pool = echoes.filter {
            $0.active && $0.lang == lang && (exposure[$0.id]?.lastSeenAt ?? .distantPast) < cutoff
        }
        // Düşük skorda skor koşulu olmayan genel cümle bile ancak koşulsuzsa seçilir;
        // skor bandı belirtip bu skoru kapsamayan hiçbir yankı seçilmez (matches).
        let conditional = pool.filter { !$0.conditions.isGeneral && matches($0.conditions, input: input, families: families, trend: trend) }
        let general = pool.filter(\.conditions.isGeneral)
        let candidates = conditional.isEmpty ? general : conditional
        guard let i = rng.weightedIndex(candidates.map(\.weight)) else { return nil }
        return candidates[i]
    }
}

final class EchoEngine {
    private let content: ContentRepository
    private let exposure: ExposureStore
    private let profile: ProfileStore
    private let clock: AppClock
    private let mood: MoodStore?

    init(content: ContentRepository, exposure: ExposureStore, profile: ProfileStore, clock: AppClock,
         mood: MoodStore? = nil) {
        self.content = content; self.exposure = exposure; self.profile = profile; self.clock = clock; self.mood = mood
    }

    /// Kaydedilmiş check-in'in yankısı: önce saklanan, yoksa seçip saklar.
    /// Aynı check-in her açılışta aynı cümleyi gösterir.
    func echo(for checkIn: MoodCheckIn, recentDailyScores: [Double] = [], isFirstCheckin: Bool = false) -> Echo? {
        if let id = checkIn.echoID, let saved = content.catalog.echoes.first(where: { $0.id == id }) { return saved }
        let input = EchoInput(score: checkIn.score, emotionIDs: checkIn.emotionIDs, causeIDs: checkIn.causeIDs,
                              dayPart: .of(hour: clock.calendar.component(.hour, from: checkIn.timestamp)),
                              isFirstCheckin: isFirstCheckin, recentDailyScores: recentDailyScores,
                              checkInID: checkIn.id.uuidString)
        guard let echo = echo(for: input) else { return nil }
        try? mood?.setEchoID(echo.id, for: checkIn.id)
        return echo
    }

    /// Kayıtlı bir yankı metni (ID ile).
    func echoText(_ id: String?) -> String? {
        id.flatMap { id in content.catalog.echoes.first { $0.id == id }?.text }
    }

    /// Yankıyı seçer ve gösterildi olarak kaydeder.
    func echo(for input: EchoInput) -> Echo? {
        var filled = input
        if filled.dayPart == .any { filled.dayPart = .of(hour: clock.calendar.component(.hour, from: clock.now)) }
        var rng = SeededRandom("echo", profile.profile.userSalt.uuidString, clock.today.string, input.checkInID)
        let snapshot = (try? exposure.snapshot(.echo)) ?? ExposureSnapshot(kind: .echo)
        guard let echo = EchoSelection.choose(content.catalog.echoes, input: filled, catalog: content.catalog,
                                              exposure: snapshot, now: clock.now, lang: profile.profile.contentLang,
                                              rng: &rng) else { return nil }
        exposure.recordSeen(echo.id, kind: .echo)
        return echo
    }
}
