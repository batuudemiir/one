//
//  Router.swift
//  ONE 2.0
//
//  Gezinme durumu tek yerde (ADR-001 §4): seçili sekme, sekme başına
//  yığın, üstte açık sheet ya da tam ekran akış. Ekranlar birbirini
//  doğrudan açmaz; `Route` / `SheetRoute` / `CoverRoute` üzerinden ister.
//  Sekmeler: Bugün · Sözler · Keşfet · Yolculuk · Eğilimler (README).
//

import Foundation
import Observation

nonisolated enum ONE2Tab: String, CaseIterable, Hashable, Sendable {
    case today, quotes, explore, journey, insights
}

/// Editörün hangi kapıdan açıldığı (README: yazmanın üç kapısı).
nonisolated enum JournalContext: Hashable, Sendable {
    /// Boş sayfa: soru yok.
    case blank
    /// Serbest ya da günün önerisi; içerik referansı (`ones://journal/new?prompt=`).
    case prompt(String)
    /// Haftalık temanın bugünkü sorusu.
    case weeklyTheme(themeID: String, day: Int)
    /// Rehberli günlük (Keşfet).
    case guided(contentID: String)
}

/// Sekme yığınına itilen ekranlar.
nonisolated enum Route: Hashable, Sendable {
    case profile
    case settings
    case themeList
    case templates
    case library
    case theme(String)
    case contentDetail(String)
    case dayDetail(DayKey)
    case entry(UUID)
}

/// Alttan açılan sayfalar.
nonisolated enum SheetRoute: Hashable, Identifiable, Sendable {
    case plusMenu
    /// `source`: paywall'ı açan yer (analitik, UX-11).
    case paywall(source: String)

    var id: String {
        switch self {
        case .plusMenu: return "plusMenu"
        case .paywall(let source): return "paywall.\(source)"
        }
    }
}

/// Tam ekran akışlar.
nonisolated enum CoverRoute: Hashable, Identifiable, Sendable {
    /// Giriş akışı (07 §5.2). `day`: geri doldurulan gün; `nil` bugün.
    case flow(FlowKind, day: DayKey?)
    case journalEditor(JournalContext)
    case quoteReflection(quoteID: String)

    var id: Self { self }
}

/// Kullanıcıya bir kez gösterilecek bilgi.
nonisolated enum RouterNotice: Hashable, Sendable {
    /// Çevre (sosyal katman) ONE 2.0'da yok; eski bir davet ya da Çevre linki açıldı.
    case circleUnavailable
}

@Observable
final class Router {
    var tab: ONE2Tab = .today
    var paths: [ONE2Tab: [Route]] = [:]
    var sheet: SheetRoute?
    var cover: CoverRoute?
    var notice: RouterNotice?

    func path(for tab: ONE2Tab) -> [Route] { paths[tab] ?? [] }

    func setPath(_ path: [Route], for tab: ONE2Tab) { paths[tab] = path }

    func push(_ route: Route, on tab: ONE2Tab? = nil) {
        let target = tab ?? self.tab
        paths[target, default: []].append(route)
        self.tab = target
    }

    func pop(on tab: ONE2Tab? = nil) {
        let target = tab ?? self.tab
        guard paths[target]?.isEmpty == false else { return }
        paths[target]?.removeLast()
    }

    func popToRoot(_ tab: ONE2Tab? = nil) { paths[tab ?? self.tab] = [] }

    /// Deep link hedefini uygular: sekme verildiyse seçilir ve yığını
    /// hedefle değiştirilir; açık sheet ve tam ekran akış hedefinkilerle
    /// değişir.
    func open(_ destination: DeepLink.Destination) {
        if let target = destination.tab {
            tab = target
            paths[target] = destination.path
        }
        sheet = destination.sheet
        cover = destination.cover
        if let notice = destination.notice { self.notice = notice }
    }

    /// `true`: bağlantı ONE 2.0 tarafından tanındı ve uygulandı.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let destination = DeepLink.destination(for: url) else { return false }
        open(destination)
        return true
    }
}
