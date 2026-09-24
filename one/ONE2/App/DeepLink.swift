//
//  DeepLink.swift
//  ONE 2.0
//
//  URL → gezinme hedefi, saf fonksiyon (ADR-001 §9). v3'ün yayımlanmış
//  link'leri (widget, bildirim, davet) ONE 2.0'da anlamlı bir yere düşer;
//  hiçbiri sessizce kaybolmaz.
//

import Foundation

nonisolated enum DeepLink {

    struct Destination: Hashable, Sendable {
        /// `nil`: sekme değişmez (ör. paywall her sekmenin üstünde açılır).
        var tab: ONE2Tab?
        var path: [Route] = []
        var sheet: SheetRoute? = nil
        var cover: CoverRoute? = nil
        var notice: RouterNotice? = nil
    }

    static let scheme = "ones"
    static let universalHosts: Set<String> = ["one.forvibe.app", "onedaily.app"]
    /// Paywall'ın deep link ile açıldığını analitiğe söyler.
    static let paywallSource = "deeplink"

    /// `nil`: link ONE 2.0'da bir hedefe karşılık gelmiyor (ör. Spotify
    /// OAuth dönüşü) ya da tanınmıyor.
    static func destination(for url: URL) -> Destination? {
        if url.scheme?.lowercased() == scheme {
            return custom(host: url.host?.lowercased() ?? "", url: url)
        }
        if let host = url.host?.lowercased(), universalHosts.contains(host) {
            return universal(path: url.path)
        }
        return nil
    }

    // MARK: - ones://

    private static func custom(host: String, url: URL) -> Destination? {
        let segments = url.pathComponents.filter { $0 != "/" }
        switch host {
        // v3 widget ve kilit ekranı: ones://today → bugün + check-in.
        case "today", "checkin":
            return Destination(tab: .today, cover: .flow(.moodCheckIn, day: nil))
        case "entry":
            return Destination(tab: .today, cover: .journalEditor(.blank))
        case "journal":
            guard segments.first == "new" else { return Destination(tab: .today) }
            let context: JournalContext = query(url, "prompt").map { .prompt($0) } ?? .blank
            return Destination(tab: .today, cover: .journalEditor(context))
        case "archive", "journey":
            return Destination(tab: .journey)
        case "echo", "insights":
            return Destination(tab: .insights)
        case "theme":
            guard let id = segments.first, !id.isEmpty else { return Destination(tab: .explore) }
            return Destination(tab: .explore, path: [.theme(id)])
        case "explore":
            return Destination(tab: .explore)
        // Profil Bugün'ün sağ üstünde.
        case "profile":
            return Destination(tab: .today, path: [.profile])
        case "paywall":
            return Destination(tab: nil, sheet: .paywall(source: paywallSource))
        // Çevre ONE 2.0'da yok (ADR-001 §10).
        case "circle", "add-friend":
            return Destination(tab: .today, notice: .circleUnavailable)
        default:
            return nil
        }
    }

    // MARK: - https://one.forvibe.app

    private static func universal(path: String) -> Destination? {
        if path.hasPrefix("/event/mood") { return Destination(tab: .today, cover: .flow(.moodCheckIn, day: nil)) }
        if path.hasPrefix("/invite") || path.hasPrefix("/add-friend") {
            return Destination(tab: .today, notice: .circleUnavailable)
        }
        return nil
    }

    private static func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == name })?.value
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}
