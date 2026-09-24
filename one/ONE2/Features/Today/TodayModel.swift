//
//  TodayModel.swift
//  ONE 2.0
//
//  Bugün ekranının verisi. Yazmanın döndüğü yer: bir söze yazıp kapanış
//  bitince Bugün açılır ve yazı "Bugün yazdıkların"da görünür.
//
//  Şimdilik: hafta şeridi, günün sözü (yazma kapısı), bugünkü yazılar.
//  Check-in kartı, Pratiklerin ve Haftalık tema UX-4/UX-5 ile gelir.
//

import Foundation
import Observation

struct TodayServices {
    var today: () -> DayKey
    var week: () -> [WeekDayCell]
    var dailyQuote: (DayKey) async -> Quote?
    var entries: (DayKey) throws -> [JournalEntry]
    var quote: (QuoteID) -> Quote?
}

/// "Bugün yazdıkların" satırı.
nonisolated struct TodayEntryItem: Hashable, Sendable, Identifiable {
    let id: UUID
    let kind: EntryKind
    let createdAt: Date
    /// Söze yazıda sözün ID'si ve metni (sol çizgili alıntı).
    let quoteID: QuoteID?
    let quoteText: String?
    let body: String

    static func from(_ entry: JournalEntry, quote: (QuoteID) -> Quote?) -> TodayEntryItem {
        let quoteID = entry.kind == .quoteReflection ? entry.contentRef : nil
        return TodayEntryItem(id: entry.id, kind: entry.kind, createdAt: entry.createdAt,
                              quoteID: quoteID, quoteText: quoteID.flatMap(quote)?.text, body: entry.body ?? "")
    }
}

nonisolated enum TodayPhase: Hashable, Sendable {
    case loading, ready, failed
}

@Observable
final class TodayModel {
    private(set) var phase: TodayPhase = .loading
    private(set) var week: [WeekDayCell] = []
    private(set) var dailyQuote: Quote?
    /// Bugünkü yazılar, en yeni önce.
    private(set) var entries: [TodayEntryItem] = []

    @ObservationIgnored private let services: TodayServices

    init(services: TodayServices) {
        self.services = services
    }

    /// Günün sözüne bugün yazıldı mı.
    var wroteAboutDailyQuote: Bool {
        guard let dailyQuote else { return false }
        return entries.contains { $0.quoteID == dailyQuote.id }
    }

    /// Her görünüşte çağrılır; yazıdan dönünce yeni girdi görünür.
    func load() async {
        let today = services.today()
        do {
            let rows = try services.entries(today)
            entries = rows.sorted { $0.createdAt > $1.createdAt }.map { TodayEntryItem.from($0, quote: services.quote) }
        } catch {
            if phase == .loading { phase = .failed }
            return
        }
        week = services.week()
        dailyQuote = await services.dailyQuote(today)
        phase = .ready
    }
}

extension TodayServices {
    static func live(_ env: AppEnvironment) -> TodayServices {
        TodayServices(
            today: { env.clock.today },
            week: { WeekStripModel.load(env) },
            dailyQuote: { await env.quotes.dailyQuote(for: $0) },
            entries: { try env.journal.entries(on: $0) },
            quote: { env.content.catalog.quote($0) }
        )
    }
}
