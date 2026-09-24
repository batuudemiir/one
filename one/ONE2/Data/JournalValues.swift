//
//  JournalValues.swift
//  ONE 2.0
//
//  Ekranların gördüğü değer tipleri (ADR-001 §1). View'lar managed object
//  tutmaz; depolar `…MO` nesnelerini bu tiplere çevirir. Alanların anlamı
//  için 02_veri_modeli.md.
//

import Foundation

nonisolated enum EntryKind: String, Codable, Sendable, CaseIterable {
    case freeform, prompt, guided, template, dailyCheckIn, morning, evening, emotionCheckIn, quoteReflection
}

nonisolated enum AnswerKind: String, Codable, Sendable, CaseIterable {
    case text, scale5, yesNo, singleChoice, multiChoice, focus, todo
}

/// Girdinin nereden başladığı (04 › E4, E17): analitik ve içgörü.
nonisolated enum EntrySource: String, Codable, Sendable, CaseIterable {
    case theme, quote, free, suggestion, comparison, guided
}

nonisolated enum MoodSource: String, Codable, Sendable, CaseIterable {
    case launch, checkIn, emotionCheckIn, widget, shortcut
}

nonisolated struct EntryAnswer: Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var order: Int = 0
    var kind: AnswerKind
    var stepRef: String?
    var questionSnapshot: String?
    var text: String?
    var number: Double?
    var bool: Bool?
    var choices: [String] = []
    var metricID: String?
}

nonisolated struct JournalEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let day: DayKey
    let timeZoneID: String?
    let createdAt: Date
    let updatedAt: Date
    let kind: EntryKind
    let title: String?
    let body: String?
    let wordCount: Int
    let contentRef: String?
    let contentSnapshot: String?
    let isBackfilled: Bool
    let sourceContext: EntrySource?
    /// Karşılaştırma zincirinde önceki cevap (E4).
    let comparedEntryID: UUID?
    let moodID: UUID?
    let tagIDs: Set<UUID>
    /// `order` sırasında.
    let answers: [EntryAnswer]
}

/// Yeni girdi için gereken her şey; kimlik, gün ve zaman damgalarını depo verir.
nonisolated struct EntryDraft: Sendable {
    var kind: EntryKind
    var title: String?
    var body: String?
    var contentRef: String?
    var contentSnapshot: String?
    var answers: [EntryAnswer] = []
    var tagIDs: Set<UUID> = []
    var sourceContext: EntrySource?
    var comparedEntryID: UUID?

    init(kind: EntryKind, title: String? = nil, body: String? = nil,
         contentRef: String? = nil, contentSnapshot: String? = nil,
         answers: [EntryAnswer] = [], tagIDs: Set<UUID> = [],
         sourceContext: EntrySource? = nil, comparedEntryID: UUID? = nil) {
        self.kind = kind; self.title = title; self.body = body
        self.contentRef = contentRef; self.contentSnapshot = contentSnapshot
        self.answers = answers; self.tagIDs = tagIDs
        self.sourceContext = sourceContext; self.comparedEntryID = comparedEntryID
    }
}

nonisolated struct MoodCheckIn: Identifiable, Hashable, Sendable {
    let id: UUID
    let day: DayKey
    let timeZoneID: String?
    let timestamp: Date
    /// 1–5.
    let score: Int
    let emotionIDs: [String]
    let causeIDs: [String]
    let note: String?
    let source: MoodSource
    let healthKitSampleID: String?
    let entryID: UUID?
    /// Bağlı girdinin türü: check-in'in ritüel dilimi buradan (`slot`).
    var entryKind: EntryKind? = nil
    /// Bu check-in'e gösterilen yankı (E6); yeniden açılışta aynı cümle.
    var echoID: String? = nil

    /// Bugün kartının dilimi: sabah/akşam ritüeli ya da günlük check-in.
    var slot: RitualCard {
        switch entryKind {
        case .morning: return .morning
        case .evening: return .evening
        default: return .daily
        }
    }
}

nonisolated struct JournalTag: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let iconName: String?
    let createdAt: Date
}

nonisolated struct EarnedBadge: Identifiable, Hashable, Sendable {
    let id: UUID
    let badgeID: String
    let earnedAt: Date
}

nonisolated struct PracticeItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let contentRef: String
    let order: Int
    let addedAt: Date
}

nonisolated enum StoreError: Error, Equatable {
    case notFound
    case invalidValue(String)
}

// MARK: - Yardımcılar

/// `[String]` alanları CloudKit'te JSON metni olarak saklanır (02_veri_modeli.md).
nonisolated enum JSONList {
    static func encode(_ values: [String]) -> String? {
        guard !values.isEmpty, let data = try? JSONEncoder().encode(values) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func decode(_ text: String?) -> [String] {
        guard let text, let data = text.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return values
    }
}

nonisolated enum WordCounter {
    /// Harf ya da rakam içeren boşlukla ayrılmış parçalar. Markdown işaretleri
    /// (`#`, `-`, `*`) tek başına kelime sayılmaz.
    static func count(_ text: String?) -> Int {
        guard let text else { return 0 }
        return text.split(whereSeparator: \.isWhitespace)
            .filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }
            .count
    }
}
