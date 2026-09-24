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
        #expect(dest("ones://today") == .init(tab: .today, sheet: .checkIn))
        #expect(dest("ones://checkin") == .init(tab: .today, sheet: .checkIn))
    }

    @Test("v3 sekme linkleri yeni karşılıklarına düşer")
    func v3Tabs() {
        #expect(dest("ones://entry") == .init(tab: .today, path: [.newEntry(prompt: nil)]))
        #expect(dest("ones://archive") == .init(tab: .journey))
        #expect(dest("ones://echo") == .init(tab: .journey, path: [.insights]))
        #expect(dest("ones://profile") == .init(tab: .profile))
        #expect(dest("ones://quotes") == .init(tab: .quotes))
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
                == .init(tab: .today, path: [.newEntry(prompt: "theme:2026-w40:d3")]))
        #expect(dest("ones://journal/new?prompt=") == .init(tab: .today, path: [.newEntry(prompt: nil)]))
        #expect(dest("ones://theme/2026-w40") == .init(tab: .explore, path: [.theme("2026-w40")]))
        #expect(dest("ones://theme") == .init(tab: .explore))
        #expect(dest("ones://paywall") == .init(tab: .profile, sheet: .paywall))
    }

    @Test("Universal link: mood etkinliği check-in açar")
    func universalMood() {
        #expect(dest("https://one.forvibe.app/event/mood") == .init(tab: .today, sheet: .checkIn))
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
        #expect(dest("ONES://Today") == .init(tab: .today, sheet: .checkIn))
    }
}

@MainActor
struct RouterTests {

    @Test("Link sekmeyi seçer, yığını değiştirir, sheet'i açar")
    func handleOpens() {
        let router = Router()
        router.push(.insights, on: .journey)
        #expect(router.handle(URL(string: "ones://theme/w40")!))
        #expect(router.tab == .explore)
        #expect(router.path(for: .explore) == [.theme("w40")])
        #expect(router.path(for: .journey) == [.insights]) // diğer sekmenin yığını korunur
        router.handle(URL(string: "ones://today")!)
        #expect(router.sheet == .checkIn)
    }

    @Test("Tanınmayan link durumu değiştirmez")
    func unknownIsNoop() {
        let router = Router()
        router.tab = .profile
        #expect(!router.handle(URL(string: "ones://spotify-callback")!))
        #expect(router.tab == .profile)
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
