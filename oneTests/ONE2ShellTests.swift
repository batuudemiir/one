//
//  ONE2ShellTests.swift
//  oneTests
//
//  ONE 2.0 kabuğu: bayrak, deep link → hedef, router, v3 temizliği.
//  v3'ün yayımlanmış link'leri (widget, bildirim, davet) ONE 2.0'da
//  sessizce kaybolmamalı (ADR-001 §9, AUDIT R14).
//

import Testing
import Foundation
@testable import OneDailyBatuhan

struct ONE2FlagTests {

    @Test("Geçersiz kılma her zaman kazanır")
    func overrideWins() {
        #expect(ONE2Flag.resolve(isDebug: true, isTestFlight: false, override: false) == false)
        #expect(ONE2Flag.resolve(isDebug: false, isTestFlight: false, override: true) == true)
    }

    @Test("Varsayılan: DEBUG ve TestFlight açık, App Store kapalı")
    func defaults() {
        #expect(ONE2Flag.resolve(isDebug: true, isTestFlight: false, override: nil))
        #expect(ONE2Flag.resolve(isDebug: false, isTestFlight: true, override: nil))
        #expect(!ONE2Flag.resolve(isDebug: false, isTestFlight: false, override: nil))
    }
}

struct DeepLinkTests {

    private func dest(_ string: String) -> DeepLink.Destination? {
        DeepLink.destination(for: URL(string: string)!)
    }

    @Test("v3 widget linki bugün + check-in açar")
    func widgetLink() {
        #expect(dest("ones://today") == .init(tab: .today, cover: .checkIn))
        #expect(dest("ones://checkin") == .init(tab: .today, cover: .checkIn))
    }

    @Test("v3 sekme linkleri yeni karşılıklarına düşer")
    func v3Tabs() {
        #expect(dest("ones://entry") == .init(tab: .today, cover: .journalEditor(.blank)))
        #expect(dest("ones://archive") == .init(tab: .journey))
        #expect(dest("ones://echo") == .init(tab: .insights))
        #expect(dest("ones://insights") == .init(tab: .insights))
    }

    @Test("Profil Bugün sekmesinde profil ekranını açar")
    func profile() {
        #expect(dest("ones://profile") == .init(tab: .today, path: [.profile]))
    }

    @Test("Çevre ve davet linkleri bilgi notuyla bugüne düşer")
    func circleLinks() {
        let expected = DeepLink.Destination(tab: .today, notice: .circleUnavailable)
        #expect(dest("ones://circle") == expected)
        #expect(dest("ones://add-friend?code=ABC123") == expected)
        #expect(dest("https://one.forvibe.app/invite?code=ABC123") == expected)
    }

    @Test("Yeni linkler: prompt'lu girdi, tema, paywall")
    func newLinks() {
        #expect(dest("ones://journal/new?prompt=theme:2026-w40:d3")
                == .init(tab: .today, cover: .journalEditor(.prompt("theme:2026-w40:d3"))))
        #expect(dest("ones://journal/new?prompt=") == .init(tab: .today, cover: .journalEditor(.blank)))
        #expect(dest("ones://journal") == .init(tab: .today))
        #expect(dest("ones://theme/2026-w40") == .init(tab: .explore, path: [.theme("2026-w40")]))
        #expect(dest("ones://theme") == .init(tab: .explore))
    }

    @Test("Paywall sekmeyi değiştirmeden sheet açar")
    func paywall() {
        #expect(dest("ones://paywall") == .init(tab: nil, sheet: .paywall(source: DeepLink.paywallSource)))
    }

    @Test("Universal link: mood etkinliği check-in açar")
    func universalMood() {
        #expect(dest("https://one.forvibe.app/event/mood") == .init(tab: .today, cover: .checkIn))
    }

    @Test("Tanınmayanlar ve Spotify dönüşü nil")
    func unknown() {
        #expect(dest("ones://spotify-callback?code=x") == nil)
        #expect(dest("ones://nope") == nil)
        #expect(dest("https://example.com/invite") == nil)
        #expect(dest("https://one.forvibe.app/") == nil)
    }

    @Test("Şema ve host büyük/küçük harf duyarsız")
    func caseInsensitive() {
        #expect(dest("ONES://Today") == .init(tab: .today, cover: .checkIn))
    }
}

@MainActor
struct RouterTests {

    @Test("Beş sekme, README sırasıyla")
    func tabs() {
        #expect(ONE2Tab.allCases == [.today, .quotes, .explore, .journey, .insights])
    }

    @Test("Link sekmeyi seçer, yığını değiştirir, tam ekran akışı açar")
    func handleOpens() {
        let router = Router()
        router.push(.dayDetail(DayKey("2026-09-23")!), on: .journey)
        #expect(router.handle(URL(string: "ones://theme/w40")!))
        #expect(router.tab == .explore)
        #expect(router.path(for: .explore) == [.theme("w40")])
        #expect(router.path(for: .journey) == [.dayDetail(DayKey("2026-09-23")!)]) // diğer sekmenin yığını korunur
        router.handle(URL(string: "ones://today")!)
        #expect(router.cover == .checkIn)
        #expect(router.sheet == nil)
    }

    @Test("Paywall linki sekmeyi ve yığını korur")
    func paywallKeepsTab() {
        let router = Router()
        router.push(.settings, on: .journey)
        router.handle(URL(string: "ones://paywall")!)
        #expect(router.tab == .journey)
        #expect(router.path(for: .journey) == [.settings])
        #expect(router.sheet == .paywall(source: DeepLink.paywallSource))
    }

    @Test("pop yalnız verilen sekmenin yığınından çıkarır")
    func pop() {
        let router = Router()
        router.push(.profile, on: .today)
        router.push(.settings, on: .today)
        router.pop(on: .today)
        #expect(router.path(for: .today) == [.profile])
        router.pop(on: .today)
        router.pop(on: .today)
        #expect(router.path(for: .today).isEmpty)
    }

    @Test("Tanınmayan link durumu değiştirmez")
    func unknownIsNoop() {
        let router = Router()
        router.tab = .insights
        #expect(!router.handle(URL(string: "ones://spotify-callback")!))
        #expect(router.tab == .insights)
    }

    @Test("Bilgi notu bir linkle gelir, kapatılana dek kalır")
    func notice() {
        let router = Router()
        router.handle(URL(string: "ones://circle")!)
        #expect(router.notice == .circleUnavailable)
        router.handle(URL(string: "ones://profile")!)
        #expect(router.notice == .circleUnavailable)
    }
}

@MainActor
struct ONE2CleanupTests {

    @Test("v3 bekleyen kimlikleri seçilir, diğerlerine dokunulmaz")
    func pendingFilter() {
        let pending = [
            "v3_daily_reminder_2026-9-24", "v3_daily_reminder_2026-9-25",
            "sunday_reflection_1", "monthly_portrait_2", "daily_reminder",
            "app_update_available", "one2.morningRitual", "something_else"
        ]
        #expect(Set(ONE2Cleanup.pendingToRemove(pending)) == [
            "v3_daily_reminder_2026-9-24", "v3_daily_reminder_2026-9-25",
            "sunday_reflection_1", "monthly_portrait_2", "daily_reminder"
        ])
    }

    @Test("Geri alınamaz temizlik TestFlight döneminde kapalı")
    func irreversibleOff() {
        #expect(!ONE2Cleanup.irreversibleEnabled)
    }
}
