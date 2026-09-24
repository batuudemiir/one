//
//  ONE2RootView.swift
//  ONE 2.0
//
//  ONE 2.0 kabuğu (ADR-001 §3, §4): sekme başına `NavigationStack`, gezinme
//  `Router`'da, bağımlılıklar `AppEnvironment`'ta. Ekranlar henüz yer
//  tutucu; her biri ekran spesifikasyonuyla (03_ekran_spesifikasyonu.md)
//  gerçek içeriğine kavuşacak. Başlıkları sistem çubuğu değil v3 kabukları
//  çiziyor (CLAUDE.md).
//

import SwiftUI

struct ONE2RootView: View {
    @Bindable var router: Router
    let environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $router.tab) {
            ForEach(ONE2Tab.allCases, id: \.self) { tab in
                NavigationStack(path: pathBinding(for: tab)) {
                    ONE2TabRoot(tab: tab)
                        .navigationDestination(for: Route.self) { ONE2RouteView(route: $0) }
                        .toolbar(.hidden, for: .navigationBar)
                }
                .tabItem { Label(tab.title, systemImage: tab.symbol) }
                .tag(tab)
            }
        }
        .tint(V3Tokens.ink)
        .sheet(item: $router.sheet) { ONE2SheetPlaceholder(sheet: $0) }
        .environment(\.one2, environment)
        .environment(router)
        .onChange(of: scenePhase) { _, phase in environment.handleScenePhase(phase) }
    }

    private func pathBinding(for tab: ONE2Tab) -> Binding<[Route]> {
        Binding(get: { router.path(for: tab) }, set: { router.setPath($0, for: tab) })
    }
}

// MARK: - Sekme

extension ONE2Tab {
    var title: String {
        switch self {
        case .today:   return NSLocalizedString("one2.tab.today", comment: "ONE 2.0 tab")
        case .quotes:  return NSLocalizedString("one2.tab.quotes", comment: "ONE 2.0 tab")
        case .journey: return NSLocalizedString("one2.tab.journey", comment: "ONE 2.0 tab")
        case .explore: return NSLocalizedString("one2.tab.explore", comment: "ONE 2.0 tab")
        case .profile: return NSLocalizedString("one2.tab.profile", comment: "ONE 2.0 tab")
        }
    }

    var symbol: String {
        switch self {
        case .today:   return "sun.max"
        case .quotes:  return "quote.opening"
        case .journey: return "book.closed"
        case .explore: return "sparkles"
        case .profile: return "person.crop.circle"
        }
    }
}

extension SheetRoute {
    var title: String {
        switch self {
        case .checkIn: return NSLocalizedString("one2.sheet.checkIn", comment: "ONE 2.0 mood check-in sheet")
        case .paywall: return NSLocalizedString("one2.sheet.paywall", comment: "ONE 2.0 paywall sheet")
        }
    }
}

// MARK: - Yer tutucular

private struct ONE2TabRoot: View {
    let tab: ONE2Tab

    var body: some View {
        switch tab {
        case .today:  TodayScreen()
        case .quotes: QuotesScreen()
        default:      placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 0) {
            V3TopBar(style: .root, title: tab.title)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
                    Text(NSLocalizedString("one2.placeholder.body", comment: "ONE 2.0 placeholder"))
                        .bodyMD()
                        .foregroundColor(V3Tokens.mutedText)
                    if tab == .profile, ONE2Flag.canOverride {
                        ShellSwitchRow()
                    }
                }
                .padding(.top, V3Tokens.spacingLG)
                .oneScreenBody()
            }
        }
        .oneScreenGround()
    }
}

/// Rota → ekran. Ekranı henüz olmayan rotalar yer tutucuda.
private struct ONE2RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .quoteReflection(let id): QuoteReflectionScreen(quoteID: id)
        case .entry(let id):           EntryDetailScreen(entryID: id)
        default:                       ONE2RoutePlaceholder(route: route)
        }
    }
}

private struct ONE2RoutePlaceholder: View {
    let route: Route
    @Environment(Router.self) private var router

    var body: some View {
        SubScreen(title: title, onBack: popOne) {
            Text(NSLocalizedString("one2.placeholder.body", comment: "ONE 2.0 placeholder"))
                .bodyMD()
                .foregroundColor(V3Tokens.mutedText)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var title: String {
        switch route {
        case .newEntry, .entry: return ONE2Tab.today.title
        case .theme:            return ONE2Tab.explore.title
        case .insights:         return ONE2Tab.journey.title
        case .quoteReflection:  return ONE2Tab.quotes.title
        }
    }

    private func popOne() {
        var path = router.path(for: router.tab)
        guard !path.isEmpty else { return }
        path.removeLast()
        router.setPath(path, for: router.tab)
    }
}

private struct ONE2SheetPlaceholder: View {
    let sheet: SheetRoute
    @Environment(Router.self) private var router

    var body: some View {
        V3SheetScreen(title: sheet.title, onClose: { router.sheet = nil }) {
            Text(NSLocalizedString("one2.placeholder.body", comment: "ONE 2.0 placeholder"))
                .bodyMD()
                .foregroundColor(V3Tokens.mutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Yalnız geliştirme ve TestFlight: bir sonraki açılışta v3 kabuğuna dön.
private struct ShellSwitchRow: View {
    @State private var didSwitch = false
    @State private var showUXPreview = false

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            V3OutlineButton(title: NSLocalizedString("one2.debug.uxPreview", comment: "Debug: new Today preview")) {
                showUXPreview = true
            }
            V3OutlineButton(title: NSLocalizedString("one2.debug.useV3", comment: "Switch back to the v3 interface on next launch")) {
                ONE2Flag.setOverride(false)
                didSwitch = true
            }
            if didSwitch {
                Text(NSLocalizedString("one2.debug.restart", comment: "Restart required"))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
            }
        }
        .sheet(isPresented: $showUXPreview) {
            UXPreviewSheet(onClose: { showUXPreview = false })
        }
    }
}
