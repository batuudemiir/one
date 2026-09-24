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

/// Akış taslağı cihazda, `one2.flow.draft.<akış>.<gün>`.
final class DefaultsFlowDraftStore: FlowDraftStoring {
    private let day: DayKey
    private let backing: KeyValueBacking

    init(day: DayKey, backing: KeyValueBacking = FlowStorage.backing) {
        self.day = day
        self.backing = backing
    }

    private func key(_ flow: FlowKind) -> String { "one2.flow.draft.\(flow.rawValue).\(day.string)" }

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
