//
//  ONE2TodayTests.swift
//  oneTests
//
//  Bugün ekranının saf mantığı (UX-4): pratik sıralama, fixture kaynağının
//  şekli (hafta sırası, gün başına veri), doldurma penceresi.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct PracticeMoveTests {

    private let list = TodayFixture.practices
    private var ids: [String] { list.map(\.id) }

    @Test("Başa al, sona al, kaldır")
    func moves() {
        let last = list[2].id
        #expect(PracticeMove.first.apply(to: list, id: last).map(\.id) == [last, ids[0], ids[1]])
        #expect(PracticeMove.last.apply(to: list, id: ids[0]).map(\.id) == [ids[1], ids[2], ids[0]])
        #expect(PracticeMove.remove.apply(to: list, id: ids[1]).map(\.id) == [ids[0], ids[2]])
    }

    @Test("Pratik işareti çevrilir, diğer alanlar korunur")
    func toggle() {
        let item = list[1]
        let toggled = item.toggled()
        #expect(toggled.isDoneToday == !item.isDoneToday)
        #expect(toggled.id == item.id && toggled.title == item.title && toggled.contentID == item.contentID)
    }

    @Test("Bilinmeyen kimlik listeyi değiştirmez")
    func unknown() {
        #expect(PracticeMove.remove.apply(to: list, id: "yok").map(\.id) == ids)
    }
}

struct TodaySourceFixtureTests {

    private let today = FixtureClock.today

    @Test("Haftalar eskiden yeniye; sonuncusu bugünü içerir")
    func weeksOrder() {
        let weeks = TodayFixture.weeks
        #expect(weeks.count == 4)
        #expect(weeks.last?.days.contains { $0.day == today } == true)
        let mondays = weeks.compactMap { $0.days.first?.day }
        #expect(mondays == mondays.sorted())
    }

    @Test("Bu hafta: pazartesi ve salı tamam, dün boş ve doldurulabilir")
    func thisWeek() throws {
        let week = try #require(TodayFixture.weeks.last)
        #expect(week.days.map(\.kind).prefix(4) == [.done, .done, .gap, .today])
        let yesterday = try #require(week.days.first { $0.day == today.adding(days: -1) })
        #expect(week.canBackfill(yesterday))
    }

    @Test("Bugün verilen veri; geçmiş gün tamamlanmaya ve 7 günlük pencereye göre")
    func dayProvider() {
        let source = TodayFixture.source(TodayFixture.done)
        #expect(source.day(today) == .loaded(TodayFixture.done))

        guard case .loaded(let done) = source.day(today.adding(days: -3)) else {
            Issue.record("geçmiş gün yüklenmedi"); return
        }
        #expect(done.checkIns.first?.summary != nil)
        #expect(done.theme == nil)
        #expect(done.practices.isEmpty)
        #expect(done.resurface == nil)

        // Dün boş: doldurulabilir, kart "başlamadı".
        guard case .loaded(let gap) = source.day(today.adding(days: -1)) else {
            Issue.record("boş gün yüklenmedi"); return
        }
        #expect(gap.checkIns.first?.status == .notStarted)

        // 9 gün önce boş: pencere dışında, kart "kayıt yok".
        guard case .loaded(let old) = source.day(today.adding(days: -9)) else {
            Issue.record("eski gün yüklenmedi"); return
        }
        #expect(old.checkIns.first?.status == .empty)
    }

    @Test("İlk gün: seri hapı ve geri dönüş yok")
    func firstDay() {
        #expect(TodayFixture.firstDay.isFirstDay)
        #expect(TodayFixture.firstDay.resurface == nil)
        #expect(TodayFixture.firstDay.practices.isEmpty)
    }

    @Test("Sabah+akşam modunda iki kart, sabah ve akşam akışları")
    func morningEvening() {
        let flows = TodayFixture.morningEvening.checkIns.map(\.flow)
        #expect(TodayFixture.morningEvening.mode == .morningEvening)
        #expect(flows == [.morning, .evening])
    }

    @Test("Geçmiş gün fixture'ı her çağrıda aynı")
    func deterministic() {
        let day = today.adding(days: -4)
        #expect(TodayFixture.pastDay(day) == TodayFixture.pastDay(day))
    }

    @Test("Ayın günü DayKey'den")
    func dayOfMonth() throws {
        let week = try #require(TodayFixture.weeks.last)
        #expect(week.days.map(\.dayOfMonth) == [21, 22, 23, 24, 25, 26, 27])
    }
}

struct ONE2CopyTests {

    private func table(_ lang: String) throws -> [String: String] {
        let bundle = Bundle(for: PersistenceController.self)
        let path = try #require(bundle.path(forResource: "ONE2", ofType: "strings", inDirectory: nil, forLocalization: lang))
        return try #require(NSDictionary(contentsOfFile: path) as? [String: String])
    }

    @Test("Marka adı dizelere elle yazılmaz (07 §0)")
    func noHardcodedBrand() throws {
        for lang in ["tr", "en"] {
            for (key, value) in try table(lang) {
                #expect(!value.contains(AppBrand.name), "\(lang) \(key): \(value)")
            }
        }
    }

    @Test("Bugün kopyası 07 §8 tablosundan")
    func copyTable() throws {
        let tr = try table("tr")
        #expect(tr["one2.today.ritual.start"] == "Başla")
        #expect(tr["one2.resurface.rewrite"] == "Tekrar yaz")
        #expect(tr["one2.today.ritual.resume"] == "Devam et · %d/%d")
        #expect(tr["one2.action.retry"] == "Tekrar dene")
        #expect(tr["one2.today.backfill.yesterday"] == "Dün boş kaldı.")
        #expect(tr["one2.today.backfill.body"] == "İstersen şimdi doldurabilirsin.")
    }
}
