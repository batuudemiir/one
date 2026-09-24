//
//  ExportAnalyticsTests.swift
//  oneTests
//
//  E16 dışa aktarma v2 ve E17 olay kataloğu (04_arka_plan_motorlari.md).
//

import Testing
import Foundation
import CoreData
@testable import OneDailyBatuhan

@MainActor
struct ExportV2Tests {

    struct Rig {
        let exporter: DataExporter
        let journal: JournalStore
        let mood: MoodStore
        let day: DayStore
        let library: LibraryStore
        let exposure: ExposureStore
        let context: NSManagedObjectContext
        let container: NSPersistentContainer
    }

    static func rig() -> Rig {
        let clock = TestClock("2026-09-23T09:00:00Z")
        let container = ONE2TestStack.makeContainer()
        let ctx = container.viewContext
        let content = ContentRepository(bundle: BundleContentSource(bundle: Bundle(for: PersistenceController.self)),
                                        cacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("x-\(UUID())"),
                                        fetcher: FakeContentFetcher(files: nil), clock: clock,
                                        defaults: UserDefaults(suiteName: "x-\(UUID())")!)
        let journal = JournalStore(context: ctx, clock: clock), mood = MoodStore(context: ctx, clock: clock)
        let day = DayStore(context: ctx, clock: clock), library = LibraryStore(context: ctx, clock: clock)
        let exposure = ExposureStore(context: ctx, clock: clock)
        let exporter = DataExporter(context: ctx, journal: journal, mood: mood, day: day, library: library,
                                    exposure: exposure, legacy: LegacyMomentStore(context: ctx, calendar: clock.calendar),
                                    content: content, clock: clock)
        return Rig(exporter: exporter, journal: journal, mood: mood, day: day, library: library,
                   exposure: exposure, context: ctx, container: container)
    }

    /// v3 satırı: normal, pas günü.
    private func legacyRow(_ ctx: NSManagedObjectContext, day: String, hex: String, passed: Bool = false) {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let midnight = DayKey(day)!.startDate(in: cal)!
        let row = NSEntityDescription.insertNewObject(forEntityName: "DailySong", into: ctx)
        row.setValue(UUID(), forKey: "id")
        row.setValue(midnight, forKey: "date")
        row.setValue(midnight.addingTimeInterval(9 * 3600), forKey: "createdAt")
        row.setValue(hex, forKey: "moodColorHex")
        row.setValue("eski not", forKey: "dailyNote")
        row.setValue(passed, forKey: "passed")
    }

    private func seed(_ r: Rig) throws {
        let tag = try r.library.createTag(name: "Uyku")
        let entry = try r.journal.create(EntryDraft(kind: .quoteReflection, body: "Söze cevabım.", contentRef: "q_000001",
                                                    answers: [EntryAnswer(kind: .text, questionSnapshot: "Bu söz ne hatırlatıyor?", text: "Sabrı")],
                                                    tagIDs: [tag.id], sourceContext: .quote))
        try r.mood.log(score: 4, emotionIDs: ["emo_huzurlu"], causeIDs: ["c_uyku"], note: "iyi", source: .checkIn, linkedTo: entry.id)
        try r.day.markCompleted(.daily)
        try r.day.setFocus("sakin kal")
        _ = try r.library.award("b_first_entry")
        try r.exposure.setLiked(true, id: "q_000002", kind: .quote)
        let media: MediaMO = r.context.insert("Media")
        media.id = UUID(); media.type = "photo"; media.data = Data([1, 2, 3])
        media.entry = try r.context.fetchOne(ONE2Entity.entry, id: entry.id, as: EntryMO.self)
        legacyRow(r.context, day: "2025-05-01", hex: "#FF3B1F")
        legacyRow(r.context, day: "2025-05-02", hex: "#123456")
        legacyRow(r.context, day: "2025-05-03", hex: "#9E9E9E", passed: true)
        try r.context.save()
    }

    @Test("JSON v2: tüm kayıtlar, katalogsuz okunur metinler, legacyMoments pas dışı satır sayısı kadar (T11)")
    func jsonContent() throws {
        let r = Self.rig()
        try seed(r)
        let (export, media) = try r.exporter.makeExport()
        #expect(export.schema == 2 && export.app == "ONE")
        #expect(export.entries.count == 1)
        let e = export.entries[0]
        #expect(e.contentText == "İnsanları rahatsız eden şeylerin kendisi değil, onlar hakkındaki yargılarıdır.")
        #expect(e.tags == ["Uyku"] && e.source == "quote" && e.answers.first?.question == "Bu söz ne hatırlatıyor?")
        #expect(e.media.first?.file?.hasPrefix("media/") == true)
        #expect(export.moods.first?.emotions.first?.label == "huzurlu")
        #expect(export.moods.first?.causes.first?.label == "Uyku")
        #expect(export.days.first?.focus == "sakin kal" && export.days.first?.completedBy == "ritual")
        #expect(export.badges.first?.title == "İlk sayfa")
        #expect(export.favorites.map(\.quoteID) == ["q_000002"] && export.favorites.first?.text != nil)
        #expect(export.legacyMoments.count == 2)
        #expect(export.legacyMoments.first { $0.moodColor == "#123456" }?.mood == nil) // serbest hex tahmin edilmez
        #expect(media.count == 1)
    }

    @Test("Yazıcı: JSON dosyası çözülebilir; Markdown premium ister, zip üretir")
    func writer() throws {
        let r = Self.rig()
        try seed(r)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("export-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let json = try r.exporter.write(.json, hasPremium: false, to: dir)
        #expect(json.lastPathComponent == "ONE-arsiv-v2-2026-09-23.json")
        let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: json)) as? [String: Any])
        #expect(object["schema"] as? Int == 2)
        #expect((object["legacyMoments"] as? [Any])?.count == 2)

        #expect(throws: DataExporter.ExportError.premiumRequired) { try r.exporter.write(.markdown, hasPremium: false, to: dir) }
        let zip = try r.exporter.write(.markdown, hasPremium: true, to: dir)
        #expect(zip.pathExtension == "zip")
        let size = try FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? Int ?? 0
        #expect(size > 100)
    }

    @Test("Markdown: gün başına dosya, söz alıntısı, cevaplar, etiketler; v3 günleri ONE 1 klasöründe")
    func markdown() throws {
        let r = Self.rig()
        try seed(r)
        let files = MarkdownArchive.render(try r.exporter.makeExport().0)
        let today = try #require(files["2026-09-23.md"])
        #expect(today.hasPrefix("# 2026-09-23"))
        #expect(today.contains("**\(MarkdownArchive.focusLabel):** sakin kal"))
        #expect(today.contains("> İnsanları rahatsız eden"))
        #expect(today.contains("**Bu söz ne hatırlatıyor?**") && today.contains("Sabrı"))
        #expect(today.contains("4/5 · huzurlu · Uyku"))
        #expect(today.contains("#Uyku") && today.contains("![](media/"))
        #expect(files.keys.filter { $0.hasPrefix("ONE 1/") }.count == 2)
    }
}

struct ONE2EventTests {

    private static let all: [ONE2Event] = [
        .onboardingStep(step: "paths"), .onboardingDone(focusCount: 2, pathCount: 1, ritualMode: .daily),
        .checkInDone(score: 3, emotionCount: 2, causeCount: 1), .ritualDone(kind: .evening),
        .dayCompleted(by: .writing, backfilled: false),
        .entrySaved(kind: .freeform, words: 42, source: .free), .comparisonShown(promptRef: "p_000003"),
        .quoteSeen(count: 7, mode: "forYou"), .quoteLiked(quoteID: "q_000001"), .quoteWriteTap(quoteID: "q_000001"),
        .contentPoolLow(mode: "forYou", remaining: 120), .streakBroken(length: 12), .backfillUsed(daysBack: 3),
        .badgeAwarded(badgeID: "b_streak_7", announced: true), .paywallShown(source: "quotes_path"),
        .trialStarted(productID: "com.batudemir.ones.oneplus.yearly"), .purchase(productID: "com.batudemir.ones.oneplus.monthly"),
        .themeMissingNextWeek(week: "2026-W41"), .contentUpdateFailed(reason: "network"),
    ]

    @Test("Adlar katalogla aynı: one2_ öneki, sağlık olayları öneksiz; hepsi benzersiz")
    func names() {
        let names = Self.all.map(\.name)
        #expect(Set(names).count == names.count)
        let unprefixed: Set = ["content_pool_low", "theme_missing_next_week", "content_update_failed"]
        #expect(names.allSatisfy { $0.hasPrefix("one2_") || unprefixed.contains($0) })
    }

    @Test("Metin içeriği gönderilmez: yalnız sayı, bool ve kısa kimlik/küme değerleri")
    func noTextContent() {
        for event in Self.all {
            for (key, value) in event.properties {
                if let s = value as? String {
                    #expect(s.count <= 40 && !s.contains(" "), "\(event.name).\(key) = \(s)")
                } else {
                    #expect(value is Int || value is Bool, "\(event.name).\(key)")
                }
            }
        }
        #expect(ONE2Event.entrySaved(kind: .freeform, words: 42, source: nil).properties["word_range"] as? String == "20-49")
    }

    @Test("Kelime aralıkları ve güncelleme hatası nedenleri")
    func mappings() {
        #expect([0, 1, 19, 20, 99, 100, 250].map(ONE2Event.wordRange) == ["0", "1-19", "1-19", "20-49", "50-99", "100-249", "250+"])
        #expect(ONE2Event.updateFailureReason(.rejected(.hashMismatch("x"))) == "hash_mismatch")
        #expect(ONE2Event.updateFailureReason(.failed) == "network")
        #expect(ONE2Event.updateFailureReason(.upToDate) == nil)
    }

    @Test("AnalyticsEvent.one2 adı ve özellikleri aynen iletir")
    @MainActor func bridge() {
        let e = AnalyticsEvent.one2(.quoteLiked(quoteID: "q_000009"))
        #expect(e.name == "one2_quote_liked")
        #expect(e.properties["quote_id"] as? String == "q_000009")
    }
}
