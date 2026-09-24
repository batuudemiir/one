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

    @Test("Bugün verilen veri, geçmiş gün tamamlanmaya göre")
    func dayProvider() {
        let source = TodayFixture.source(TodayFixture.many)
        #expect(source.day(today) == .loaded(TodayFixture.many))

        guard case .loaded(let done) = source.day(today.adding(days: -3)) else {
            Issue.record("geçmiş gün yüklenmedi"); return
        }
        #expect(done.checkIns.first?.summary != nil)
        #expect(done.theme == nil)

        guard case .loaded(let gap) = source.day(today.adding(days: -1)) else {
            Issue.record("boş gün yüklenmedi"); return
        }
        #expect(gap.checkIns.first?.summary == nil)
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
