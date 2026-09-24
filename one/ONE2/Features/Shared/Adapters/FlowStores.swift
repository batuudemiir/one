//
//  FlowStores.swift
//  ONE 2.0
//
//  Akışların cihazdaki kayıtları: yarım kalan akışın taslağı ve tamamlanan
//  kartın yankısı / mood hapı (UX_istekleri.md › 5, 7). CloudKit'e gitmez.
//

import Foundation

/// Akış adımlarını besleyen içerik. Fixture'da `ux_fixtures.tr.json`,
/// canlıda motorlardan (`LiveFlows.seed`).
typealias FlowSeedContent = UXFixtureContent

enum FlowStorage {
    static let appGroup = "group.com.batudemir.ones"
    static var backing: KeyValueBacking { UserDefaults(suiteName: appGroup) ?? .standard }
}

// MARK: - Taslak

/// Akış taslağı cihazda, `one2.flow.draft.<akış>[.<kapsam>].<gün>`.
/// Kapsam: aynı türün farklı içerikleri (rehberli günlük ID'si).
final class DefaultsFlowDraftStore: FlowDraftStoring {
    private let day: DayKey
    private let scope: String?
    private let backing: KeyValueBacking

    init(day: DayKey, scope: String? = nil, backing: KeyValueBacking = FlowStorage.backing) {
        self.day = day
        self.scope = scope
        self.backing = backing
    }

    private func key(_ flow: FlowKind) -> String {
        "one2.flow.draft.\(flow.rawValue)\(scope.map { "." + $0 } ?? "").\(day.string)"
    }

    func load(_ flow: FlowKind) -> FlowProgress? {
        guard let data = backing.object(forKey: key(flow)) as? Data else { return nil }
        return try? JSONDecoder().decode(FlowProgress.self, from: data)
    }

    func save(_ progress: FlowProgress) {
        backing.set(try? JSONEncoder().encode(progress), forKey: key(progress.flow))
    }

    func clear(_ flow: FlowKind) {
        backing.set(nil, forKey: key(flow))
    }
}

// MARK: - Tamamlanan kart

/// Bugün kartının "tamam" hâli: yankı, mood hapı, akşam pratik sayısı.
nonisolated struct FlowCompletionRecord: Codable, Hashable, Sendable {
    var echo: String
    var score: Int?
    var emotionLabels: [String] = []
    var practicesDone: Int?
}

final class FlowCompletionStore {
    private let backing: KeyValueBacking

    init(backing: KeyValueBacking = FlowStorage.backing) { self.backing = backing }

    private func key(_ flow: FlowKind, _ day: DayKey) -> String { "one2.flow.done.\(flow.rawValue).\(day.string)" }

    func load(_ flow: FlowKind, on day: DayKey) -> FlowCompletionRecord? {
        guard let data = backing.object(forKey: key(flow, day)) as? Data else { return nil }
        return try? JSONDecoder().decode(FlowCompletionRecord.self, from: data)
    }

    func save(_ record: FlowCompletionRecord, _ flow: FlowKind, on day: DayKey) {
        backing.set(try? JSONEncoder().encode(record), forKey: key(flow, day))
    }
}

// MARK: - Taşınan maddeler

/// Akşam "Taşı" dediği sabah maddeleri; ertesi sabahın öncelik listesine
/// başlangıç cevabı olur, sabah tamamlanınca silinir. `one2.flow.carry.<gün>`.
final class CarryOverStore {
    private let backing: KeyValueBacking

    init(backing: KeyValueBacking = FlowStorage.backing) { self.backing = backing }

    private func key(_ day: DayKey) -> String { "one2.flow.carry.\(day.string)" }

    func items(for day: DayKey) -> [String] {
        (backing.object(forKey: key(day)) as? [String]) ?? []
    }

    func carry(_ items: [String], to day: DayKey) {
        let filled = items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        backing.set(filled.isEmpty ? nil : Array(filled.prefix(3)), forKey: key(day))
    }

    func clear(_ day: DayKey) {
        backing.set(nil, forKey: key(day))
    }
}
