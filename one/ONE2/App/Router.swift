//
//  Router.swift
//  ONE 2.0
//
//  Gezinme durumu tek yerde (ADR-001 §4): seçili sekme, sekme başına
//  yığın, üstte açık sheet. Ekranlar birbirini doğrudan açmaz; `Route`
//  üzerinden ister. Sekme kümesi ekran spesifikasyonunda kesinleşecek.
//

import Foundation
import Observation

nonisolated enum ONE2Tab: String, CaseIterable, Hashable, Sendable {
    case today, quotes, journey, explore, profile
}

nonisolated enum Route: Hashable, Sendable {
    case newEntry(prompt: String?)
    case entry(UUID)
    case theme(String)
    case insights
    /// Söze yazı (QuoteReflection, UX-6).
    case quoteReflection(QuoteID)
}

nonisolated enum SheetRoute: String, Hashable, Identifiable, Sendable {
    case checkIn, paywall
    var id: String { rawValue }
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
    var notice: RouterNotice?

    func path(for tab: ONE2Tab) -> [Route] { paths[tab] ?? [] }

    func setPath(_ path: [Route], for tab: ONE2Tab) { paths[tab] = path }

    func push(_ route: Route, on tab: ONE2Tab? = nil) {
        let target = tab ?? self.tab
        paths[target, default: []].append(route)
        self.tab = target
    }

    func popToRoot(_ tab: ONE2Tab? = nil) { paths[tab ?? self.tab] = [] }

    /// Deep link hedefini uygular: sekme seçilir, yığın hedefle değiştirilir,
    /// açık sheet kapanıp istenen açılır.
    func open(_ destination: DeepLink.Destination) {
        tab = destination.tab
        paths[destination.tab] = destination.path
        sheet = destination.sheet
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
