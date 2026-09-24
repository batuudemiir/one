//
//  ONE2FlowTests.swift
//  oneTests
//
//  Giriş akışları (UX-5, 07 §5.2): ilerleme kuralları, taslaktan devam,
//  adım sırası belgeyle aynı, açılış check-in'i, Bugün kartına yansıma.
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct FlowSessionTests {

    @Test("Skor seçilmeden ilerlenmez; seçilince ilerler")
    func scoreRequired() {
        var session = FlowSession(flow: FlowFixture.moodCheckIn())
        #expect(session.step.kind == .score)
        #expect(!session.canContinue)
        session.next()
        #expect(session.index == 0)
        session.set(.score(4), for: session.step.id)
        session.next()
        #expect(session.index == 1)
    }

    @Test("Skor dışındaki adımlar boş geçilebilir; Atla yalnız isteğe bağlıda")
    func optionalSteps() {
        var session = FlowSession(flow: FlowFixture.evening())
        session.set(.score(3), for: session.step.id)
        session.next()
        #expect(session.step.kind == .emotions)
        #expect(session.showsSkip)
        session.skip()
        session.skip() // nedenler
        #expect(session.step.kind == .intentionReview)
        #expect(!session.showsSkip)
        #expect(session.canContinue)
    }

    @Test("Atla adımın cevabını bırakır")
    func skipClearsAnswer() {
        var session = FlowSession(flow: FlowFixture.moodCheckIn())
        session.set(.score(2), for: "mood.score")
        session.next()
        session.set(.emotions(["kaygi.gergin"]), for: "mood.emotions")
        session.skip()
        #expect(session.answers["mood.emotions"] == nil)
        #expect(session.answers["mood.score"] == .score(2))
    }

    @Test("Son adımda ilerlemek akışı bitirir; geri ilk adımda durur")
    func finishAndBack() {
        var session = FlowSession(flow: FlowFixture.moodCheckIn())
        session.back()
        #expect(session.index == 0)
        session.set(.score(5), for: "mood.score")
        for _ in 0..<session.total { session.next() }
        #expect(session.isFinished)
        #expect(session.score == 5)
    }

    @Test("Taslaktan devam: kaldığı adım ve önceki cevaplar")
    func resumeFromDraft() {
        let session = FlowSession(flow: FlowFixture.dailyResumed)
        #expect(session.index == 2)
        #expect(session.step.kind == .causes)
        #expect(session.answers["daily.score"] == .score(3))

        let draft = session.draft(at: FixtureClock.now)
        #expect(draft.stepIndex == 2)
        #expect(draft.day == FixtureClock.today)
        let resumed = FlowSession(flow: FlowFixture.dailyCheckIn(draft: draft))
        #expect(resumed.index == session.index)
        #expect(resumed.answers == session.answers)
    }

    @Test("Boş yazı ve boş seçim içerik sayılmaz")
    func hasContent() {
        #expect(!FlowAnswerData.text("  \n").hasContent)
        #expect(FlowAnswerData.text("bir").hasContent)
        #expect(!FlowAnswerData.list3(["", " ", ""]).hasContent)
        #expect(FlowAnswerData.list3(["", "iki", ""]).hasContent)
        #expect(!FlowAnswerData.emotions([]).hasContent)
    }
}

struct FlowFixtureTests {

    private func kinds(_ flow: FlowViewData) -> [FlowStepKind] { flow.steps.map(\.kind) }

    @Test("Adım sırası 07 §5.2 ile aynı")
    func stepOrder() {
        #expect(kinds(FlowFixture.moodCheckIn()) == [.score, .emotions, .causes, .text])
        #expect(kinds(FlowFixture.dailyCheckIn()) == [.score, .emotions, .causes, .text, .list3])
        #expect(kinds(FlowFixture.morning()) == [.sleep, .score, .focus, .quote, .list3, .text])
        #expect(kinds(FlowFixture.evening()) == [.score, .emotions, .causes, .intentionReview, .practices, .text, .text, .list3, .text])
    }

    @Test("Sabah yapılmadıysa akşamda niyet adımı yok")
    func eveningWithoutMorning() {
        #expect(!kinds(FlowFixture.evening(morningFocus: nil)).contains(.intentionReview))
        #expect(FlowFixture.evening(morningFocus: nil).carryOver.isEmpty)
    }

    @Test("Skor hiçbir akışta isteğe bağlı değil; adım kimlikleri benzersiz")
    func scoreNeverOptional() {
        for kind in FlowKind.allCases {
            let flow = FlowFixture.flow(kind)
            #expect(flow.steps.filter { $0.kind == .score }.allSatisfy { !$0.optional })
            #expect(Set(flow.steps.map(\.id)).count == flow.steps.count)
        }
    }

    @Test("Kapanışlar: yankı, gün hazır (yarım), bugün kapandı, ilk gün")
    func closings() {
        #expect(FlowFixture.moodCheckIn().closing == .echo)
        #expect(FlowFixture.moodCheckIn(first: true).closing == .seal(.firstDay))
        #expect(FlowFixture.morning().closing == .seal(.dayReady))
        #expect(SealKind.dayReady.isHalf)
        #expect(FlowFixture.dailyCheckIn().closing == .seal(.dayClosed))
        #expect(FlowFixture.evening().closing == .seal(.dayClosed))
    }

    @Test("Odak seçenekleri 07 sırasıyla ve sonda kendi kelimen")
    func focusOptions() {
        #expect(FlowFixture.focusOptions.count == 9)
        #expect(FlowFixture.focusOptions.last?.isCustomEntry == true)
        #expect(FlowFixture.causes.filter { !$0.isCustomEntry }.count == 11)
    }
}

struct LaunchCheckInTests {

    private func open(_ enabled: Bool = true, first: Bool = true, link: Bool = false,
                      mode: RitualModeData = .daily, hour: Int = 20) -> Bool {
        LaunchCheckIn.shouldOpen(isEnabled: enabled, isFirstOpenToday: first, openedViaLink: link, mode: mode, hour: hour)
    }

    @Test("Ayar açık, günün ilk açılışı, bağlantısız: açılır")
    func opens() { #expect(open()) }

    @Test("Ayar kapalı, ikinci açılış ya da bağlantıyla açılış: açılmaz")
    func blocked() {
        #expect(!open(false))
        #expect(!open(first: false))
        #expect(!open(link: true))
    }

    @Test("Sabah+akşam modunda 05–14 arası açılmaz, sonrası açılır")
    func morningEvening() {
        #expect(!open(mode: .morningEvening, hour: 5))
        #expect(!open(mode: .morningEvening, hour: 13))
        #expect(open(mode: .morningEvening, hour: 14))
        #expect(open(mode: .morningEvening, hour: 4))
    }
}

@MainActor
struct RouterLinkTests {

    @Test("Bağlantıyla açılış kaydedilir; tanınmayan bağlantı kaydedilmez")
    func openedFromLink() {
        let router = Router()
        #expect(!router.handle(URL(string: "ones://spotify-callback")!))
        #expect(!router.openedFromLink)
        router.handle(URL(string: "ones://checkin")!)
        #expect(router.openedFromLink)
    }
}

struct TodayFlowOverlayTests {

    @Test("Taslak kartı 'Devam et · n/m' yapar, bitiş 'tamam'")
    func overlay() {
        let draft = FlowDraftData(day: FixtureClock.today, stepIndex: 2, answers: [:], updatedAt: FixtureClock.now)
        let total = FlowFixture.dailyCheckIn().steps.count
        let inProgress = TodayFixture.app(drafts: [.dailyCheckIn: draft], finished: [:])
        guard case .loaded(let data) = inProgress.day(FixtureClock.today) else { Issue.record("yüklenmedi"); return }
        #expect(data.checkIns.first?.status == .inProgress(step: 3, total: total))

        var session = FlowSession(flow: FlowFixture.dailyCheckIn())
        session.set(.score(4), for: "daily.score")
        let finished = TodayFixture.app(drafts: [:], finished: [.dailyCheckIn: session])
        guard case .loaded(let done) = finished.day(FixtureClock.today) else { Issue.record("yüklenmedi"); return }
        #expect(done.checkIns.first?.summary?.score == 4)
    }
}
