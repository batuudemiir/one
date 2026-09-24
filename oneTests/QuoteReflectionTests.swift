//
//  QuoteReflectionTests.swift
//  oneTests
//
//  UX-6: söze yazı → kayıt sözleşmesi, taslak, "başka soru", kapanış;
//  hafta şeridi; Bugün'e dönüş.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

@MainActor
final class ReflectionFakes {
    let quote = Quote(id: "q_000007", text: "Yavaşlamak da bir adımdır.", kind: .reflection)
    var prompts: [PromptSuggestion] = (1...3).map {
        PromptSuggestion(ref: "p_00000\($0)", text: "Soru \($0)?", source: .reflection, promptID: "p_00000\($0)")
    }
    var previous: [JournalEntry] = []
    var saved: [EntryDraft] = []
    var written: [(QuoteID, UUID)] = []
    var promptRequests: [Set<PromptID>] = []
    var failSave = false
    var completedDay = true
    let drafts = MemoryKeyValueStore()

    static func entry(_ draft: EntryDraft, id: UUID = UUID(), day: DayKey = DayKey("2026-09-24")!,
                      at date: Date = Date(timeIntervalSince1970: 1_790_000_000)) -> JournalEntry {
        JournalEntry(id: id, day: day, timeZoneID: nil, createdAt: date, updatedAt: date, kind: draft.kind,
                     title: nil, body: draft.body, wordCount: WordCounter.count(draft.body),
                     contentRef: draft.contentRef, contentSnapshot: draft.contentSnapshot, isBackfilled: false,
                     sourceContext: draft.sourceContext, comparedEntryID: nil, moodID: nil, tagIDs: [],
                     answers: draft.answers)
    }

    var services: QuoteReflectionServices {
        QuoteReflectionServices(
            quote: { [quote] in $0 == quote.id ? quote : nil },
            prompt: { [unowned self] _, excluding in
                promptRequests.append(excluding)
                return prompts.first { !excluding.contains($0.ref) }
            },
            previous: { [unowned self] _ in previous },
            save: { [unowned self] draft in
                if failSave { throw StoreError.invalidValue("test") }
                saved.append(draft)
                return WritingOutcome(entry: Self.entry(draft), completedDay: completedDay,
                                      badges: [])
            },
            recordWritten: { [unowned self] in written.append(($0, $1)) },
            week: { WeekStripModel.week(containing: DayKey("2026-09-24")!, completions: [], mode: .daily) },
            drafts: drafts
        )
    }
}

@MainActor
struct QuoteReflectionTests {

    // MARK: - Söze yazı

    @Test("Kayıt sözleşmesi: quoteReflection, contentRef = söz, soru stepRef'te; söze wroteAbout; kapanış")
    func saveContract() async throws {
        let fakes = ReflectionFakes()
        let model = QuoteReflectionModel(quoteID: fakes.quote.id, services: fakes.services)
        await model.load()
        #expect(model.phase == .writing && model.prompt?.ref == "p_000001")
        #expect(!model.canSave)

        model.text = "  Bugün yavaşladım ve bir şey fark ettim.  "
        await model.save()
        let draft = try #require(fakes.saved.first)
        #expect(draft.kind == .quoteReflection && draft.contentRef == "q_000007" && draft.sourceContext == .quote)
        #expect(draft.body == "Bugün yavaşladım ve bir şey fark ettim.")
        #expect(draft.contentSnapshot == "Soru 1?")
        #expect(draft.answers.map(\.stepRef) == ["p_000001"] && draft.answers.first?.questionSnapshot == "Soru 1?")

        guard case .sealed(let seal) = model.phase else { Issue.record("kapanış yok"); return }
        #expect(seal.completedDay && seal.wordCount == 7 && seal.week.count == 7)
        #expect(fakes.written.map(\.0) == ["q_000007"] && fakes.written.first?.1 == seal.entryID)
        #expect(!model.canSave) // ikinci kayıt yok
    }

    @Test("Taslak: her değişimde saklanır, yeniden açınca döner, kayıtla silinir")
    func draftPersists() async {
        let fakes = ReflectionFakes()
        let first = QuoteReflectionModel(quoteID: fakes.quote.id, services: fakes.services)
        await first.load()
        first.text = "Yarım kalan"
        let second = QuoteReflectionModel(quoteID: fakes.quote.id, services: fakes.services)
        await second.load()
        #expect(second.text == "Yarım kalan")

        second.text = "   "
        #expect(fakes.drafts.object(forKey: "draft.quoteReflection.q_000007") == nil)
        second.text = "Bitti bu"
        await second.save()
        #expect(fakes.drafts.object(forKey: "draft.quoteReflection.q_000007") == nil)
    }

    @Test("Başka soru: bu yazışta gösterilenler hariç; havuz bitince soru değişmez")
    func anotherPrompt() async {
        let fakes = ReflectionFakes()
        let model = QuoteReflectionModel(quoteID: fakes.quote.id, services: fakes.services)
        await model.load()
        await model.anotherPrompt()
        #expect(model.prompt?.ref == "p_000002")
        await model.anotherPrompt()
        #expect(model.prompt?.ref == "p_000003")
        #expect(fakes.promptRequests.last == ["p_000001", "p_000002"])
        await model.anotherPrompt()
        #expect(model.prompt?.ref == "p_000003")
    }

    @Test("Önceki yazı: en sonuncusu 'Geçen sefer' satırında")
    func previousEntry() async {
        let fakes = ReflectionFakes()
        let old = ReflectionFakes.entry(EntryDraft(kind: .quoteReflection, body: "Eski cevap\nikinci satır", contentRef: "q_000007"))
        let newer = ReflectionFakes.entry(EntryDraft(kind: .quoteReflection, body: "Yeni cevap", contentRef: "q_000007"))
        fakes.previous = [old, newer]
        let model = QuoteReflectionModel(quoteID: fakes.quote.id, services: fakes.services)
        await model.load()
        #expect(model.previous?.id == newer.id)
        #expect(JournalCopy.firstLine(old.body) == "Eski cevap")
        #expect(JournalCopy.firstLine(String(repeating: "a", count: 100), limit: 10) == "aaaaaaaaa…")
    }

    @Test("Kayıt hatası: yazı ve taslak kalır, tekrar denenebilir; bilinmeyen söz boş durum")
    func failures() async {
        let fakes = ReflectionFakes()
        fakes.failSave = true
        let model = QuoteReflectionModel(quoteID: fakes.quote.id, services: fakes.services)
        await model.load()
        model.text = "Kaybolmasın"
        await model.save()
        #expect(model.saveFailed && model.phase == .writing && model.canSave)
        #expect(fakes.drafts.object(forKey: "draft.quoteReflection.q_000007") as? String == "Kaybolmasın")
        #expect(fakes.written.isEmpty)

        let missing = QuoteReflectionModel(quoteID: "q_yok", services: fakes.services)
        await missing.load()
        #expect(missing.phase == .missing)
    }

    @Test("Kapanış başlığı: gün kapandıysa onu söyler")
    func sealTitle() {
        #expect(JournalCopy.sealTitle(completedDay: true) != JournalCopy.sealTitle(completedDay: false))
    }

    // MARK: - Hafta şeridi

    @Test("Hafta: pazartesiden pazara; kapanan tik, yarım, açık, gelecek; bugün işaretli")
    func weekStrip() {
        let today = DayKey("2026-09-24")! // perşembe
        let completions = [
            DayCompletion(day: DayKey("2026-09-21")!, dailyCompletedAt: Date()),
            DayCompletion(day: DayKey("2026-09-22")!, morningCompletedAt: Date()),
            DayCompletion(day: DayKey("2026-09-24")!, completedBy: .writing),
            DayCompletion(day: DayKey("2026-09-14")!, dailyCompletedAt: Date()), // önceki hafta
        ]
        let daily = WeekStripModel.week(containing: today, completions: completions, mode: .daily)
        #expect(daily.map(\.day.string) == ["2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24",
                                            "2026-09-25", "2026-09-26", "2026-09-27"])
        #expect(daily.map(\.state) == [.done, .open, .open, .done, .future, .future, .future])
        #expect(daily.filter(\.isToday).map(\.day) == [today])

        let ritual = WeekStripModel.week(containing: today, completions: completions, mode: .morningEvening)
        #expect(ritual[1].state == .half)
        #expect(WeekStripModel.symbolIndex(for: DayKey("2026-09-27")!) == 0) // pazar
    }

    // MARK: - Bugün

    @Test("Yazma bitti: yazılan sekmenin yığını kapanır, Bugün köküne geçilir")
    func finishWriting() {
        let router = Router()
        router.tab = .quotes
        router.push(.quoteReflection("q_000007"))
        router.push(.entry(UUID()), on: .today)
        router.tab = .quotes
        router.sheet = .paywall
        router.finishWriting()
        #expect(router.tab == .today && router.path(for: .quotes).isEmpty && router.path(for: .today).isEmpty)
        #expect(router.sheet == nil)
    }
}
