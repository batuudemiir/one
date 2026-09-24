//
//  QuoteReflectionModel.swift
//  ONE 2.0
//
//  Söze yazı (QuoteReflection.md, UX-6). Bir sözün üzerine yazma ekranının
//  durumu; servislere kapanışlarla bağlanır, testte sahteleriyle kurulur.
//
//  Kayıt sözleşmesi (E4, E10 bunu okur):
//  - `kind = quoteReflection`, `contentRef = <söz ID>`
//  - `contentSnapshot` = gösterilen sorunun kopyası (02_veri_modeli.md)
//  - `answers[0].stepRef` = soru ID'si: aynı söze ikinci yazışta farklı soru
//  - `body` = yazının kendisi (kelime sayısı, gün tamamlama, arama)
//  - `sourceContext = quote`
//  Kayıttan sonra söze `wroteAbout` gider (kart rozeti, 90 gün geri dönüş).
//
//  Taslak: metin her değişimde cihazda saklanır, çıkışta kaybolmaz; kayıtla
//  silinir.
//

import Foundation
import Observation

/// Söze yazının dış bağımlılıkları.
struct QuoteReflectionServices {
    var quote: (QuoteID) -> Quote?
    /// Söze yazı sorusu; ikinci parametre bu yazışta zaten gösterilenler.
    var prompt: (QuoteID, Set<PromptID>) async -> PromptSuggestion?
    /// Bu söze önceki yazılar, eskiden yeniye.
    var previous: (QuoteID) -> [JournalEntry]
    var save: (EntryDraft) throws -> WritingOutcome
    var recordWritten: (QuoteID, UUID) async -> Void
    /// Kayıttan sonraki hafta (Seal şeridi).
    var week: () -> [WeekDayCell]
    var drafts: KeyValueBacking
}

/// Kapanış ekranının verisi (Seal.md).
nonisolated struct ReflectionSeal: Hashable, Sendable {
    let entryID: UUID
    let completedDay: Bool
    let wordCount: Int
    let badges: [String]
    let week: [WeekDayCell]
}

nonisolated enum ReflectionPhase: Hashable, Sendable {
    case loading
    /// Söz katalogda yok (kaldırılmış ya da hatalı bağlantı).
    case missing
    case writing
    case sealed(ReflectionSeal)
}

@Observable
final class QuoteReflectionModel {
    let quoteID: QuoteID

    private(set) var phase: ReflectionPhase = .loading
    private(set) var quote: Quote?
    private(set) var prompt: PromptSuggestion?
    /// Bu söze en son yazılan (en alttaki "Geçen sefer" satırı).
    private(set) var previous: JournalEntry?
    private(set) var isSaving = false
    private(set) var saveFailed = false
    var text = "" {
        didSet { if text != oldValue { storeDraft() } }
    }

    @ObservationIgnored private let services: QuoteReflectionServices
    @ObservationIgnored private var shownPrompts: Set<PromptID> = []

    init(quoteID: QuoteID, services: QuoteReflectionServices) {
        self.quoteID = quoteID
        self.services = services
    }

    var wordCount: Int { WordCounter.count(text) }
    var canSave: Bool { !trimmed.isEmpty && !isSaving && phase == .writing }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var draftKey: String { "draft.quoteReflection.\(quoteID)" }

    // MARK: - Yükleme

    func load() async {
        guard let quote = services.quote(quoteID) else { phase = .missing; return }
        self.quote = quote
        previous = services.previous(quoteID).last
        text = services.drafts.object(forKey: draftKey) as? String ?? ""
        prompt = await services.prompt(quoteID, [])
        if let prompt { shownPrompts.insert(prompt.ref) }
        phase = .writing
    }

    /// "Başka soru": bu yazışta gösterilmeyen bir soru.
    func anotherPrompt() async {
        guard let next = await services.prompt(quoteID, shownPrompts) else { return }
        prompt = next
        shownPrompts.insert(next.ref)
    }

    // MARK: - Kayıt

    /// "Bitti". Başarılıysa faz `sealed` olur.
    func save() async {
        guard canSave, let quote else { return }
        isSaving = true
        saveFailed = false
        defer { isSaving = false }
        let answers = prompt.map { [EntryAnswer(kind: .text, stepRef: $0.ref, questionSnapshot: $0.text)] } ?? []
        let draft = EntryDraft(kind: .quoteReflection, body: trimmed, contentRef: quote.id,
                               contentSnapshot: prompt?.text, answers: answers, sourceContext: .quote)
        do {
            let outcome = try services.save(draft)
            await services.recordWritten(quote.id, outcome.entry.id)
            services.drafts.set(nil, forKey: draftKey)
            phase = .sealed(ReflectionSeal(entryID: outcome.entry.id, completedDay: outcome.completedDay,
                                           wordCount: outcome.entry.wordCount,
                                           badges: outcome.badges.map(\.title), week: services.week()))
        } catch {
            saveFailed = true
        }
    }

    private func storeDraft() {
        services.drafts.set(trimmed.isEmpty ? nil : text, forKey: draftKey)
    }
}

extension QuoteReflectionServices {
    /// Uygulamanın gerçek depoları ve motorlarıyla.
    static func live(_ env: AppEnvironment) -> QuoteReflectionServices {
        QuoteReflectionServices(
            quote: { env.content.catalog.quote($0) },
            prompt: { await env.prompts.reflectionPrompt(for: $0, compare: false, excluding: $1) },
            previous: { (try? env.journal.entries(kind: .quoteReflection, contentRef: $0)) ?? [] },
            save: { draft in
                let entry = try env.journal.create(draft)
                if let outcome = env.lastWriting, outcome.entry.id == entry.id { return outcome }
                return WritingOutcome(entry: entry, completedDay: false, badges: [])
            },
            recordWritten: { await env.quotes.record(.wroteAbout($1), for: $0) },
            week: { WeekStripModel.load(env) },
            drafts: UserDefaults(suiteName: "group.com.batudemir.ones") ?? .standard
        )
    }
}

extension WeekStripModel {
    /// Bu haftanın hücreleri, gerçek gün kayıtlarından.
    static func load(_ env: AppEnvironment) -> [WeekDayCell] {
        let today = env.clock.today
        let monday = today.adding(days: 1 - today.isoWeekday)
        let completions = (try? env.day.completions(from: monday, through: monday.adding(days: 6))) ?? []
        return week(containing: today, completions: completions, mode: env.profile.profile.ritualMode)
    }
}
