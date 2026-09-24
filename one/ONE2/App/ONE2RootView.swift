//
//  ONE2RootView.swift
//  ONE 2.0
//
//  ONE 2.0 kabuğu (ADR-001 §3, §4; ADR-002): sekme başına `NavigationStack`,
//  gezinme `Router`'da, bağımlılıklar `AppEnvironment`'ta. Sistem tab bar'ı
//  gizli; alta yüzen cam dock (5 sekme + + hapı). İçerik dock'un altından
//  kayar, ekranlar dock yüksekliği kadar alt boşluk bırakır
//  (`one2DockInset`). Yığına ekran itilince dock gizlenir.
//

import SwiftUI

struct ONE2RootView: View {
    @Bindable var router: Router
    let environment: AppEnvironment

    @State private var dockHeight: CGFloat = 0
    /// + sayfası kapanınca açılacak hedef (sheet ile cover aynı anda sunulmaz).
    @State private var pendingPlus: PlusAction?

    private var showsDock: Bool { router.path(for: router.tab).isEmpty }

    var body: some View {
        TabView(selection: $router.tab) {
            ForEach(ONE2Tab.allCases, id: \.self) { tab in
                NavigationStack(path: pathBinding(for: tab)) {
                    tabRoot(tab)
                        .navigationDestination(for: Route.self) { routeScreen($0, on: tab) }
                        .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(tab)
            }
        }
        .environment(\.one2DockInset, showsDock ? dockHeight : 0)
        .overlay(alignment: .bottom) {
            if showsDock {
                ONE2Dock(
                    items: ONE2Tab.allCases.map { ONE2TabBarItem(tab: $0, title: $0.title, icon: $0.icon) },
                    selection: $router.tab,
                    addLabel: one2String("one2.action.add"),
                    onAdd: { router.sheet = .plusMenu }
                )
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { dockHeight = $0 }
                .ignoresSafeArea(.container, edges: .bottom)
                .ignoresSafeArea(.keyboard)
            }
        }
        .sheet(item: $router.sheet, onDismiss: runPendingPlus) { sheetScreen($0) }
        .fullScreenCover(item: $router.cover) { coverScreen($0) }
        .tint(ONE2Color.ink)
        .environment(\.one2, environment)
        .environment(router)
    }

    private func pathBinding(for tab: ONE2Tab) -> Binding<[Route]> {
        Binding(get: { router.path(for: tab) }, set: { router.setPath($0, for: tab) })
    }

    // MARK: - Ekranlar

    @ViewBuilder
    private func tabRoot(_ tab: ONE2Tab) -> some View {
        switch tab {
        case .today:    TodayScreen(clock: environment.clock, source: TodayFixture.app)
        case .quotes:   QuotesScreen()
        case .explore:  ExploreScreen()
        case .journey:  JourneyScreen()
        case .insights: InsightsScreen()
        }
    }

    @ViewBuilder
    private func routeScreen(_ route: Route, on tab: ONE2Tab) -> some View {
        switch route {
        case .profile:
            ProfileScreen { router.pop(on: tab) }
        default:
            RoutePlaceholderScreen(title: route.title) { router.pop(on: tab) }
        }
    }

    @ViewBuilder
    private func sheetScreen(_ sheet: SheetRoute) -> some View {
        switch sheet {
        case .plusMenu:
            PlusSheet { action in
                pendingPlus = action
                router.sheet = nil
            }
        case .paywall:
            CoverPlaceholderScreen(title: one2String("one2.route.paywall")) { router.sheet = nil }
                .presentationCornerRadius(ONE2Radius.xl)
        }
    }

    private func coverScreen(_ cover: CoverRoute) -> some View {
        CoverPlaceholderScreen(title: cover.title) { router.cover = nil }
    }

    private func runPendingPlus() {
        guard let action = pendingPlus else { return }
        pendingPlus = nil
        switch action {
        case .blank:       router.cover = .journalEditor(.blank)
        case .checkIn:     router.cover = .checkIn
        case .dailyPrompt: router.cover = .journalEditor(.prompt(TodayFixture.freePromptID))
        case .templates:   router.push(.templates)
        case .library:     router.push(.library)
        }
    }
}

// MARK: - Başlık ve ikonlar

extension ONE2Tab {
    var title: String { one2String("one2.tab.\(rawValue)") }

    var icon: ONE2Icon {
        switch self {
        case .today:    return .today
        case .quotes:   return .quotes
        case .explore:  return .explore
        case .journey:  return .journey
        case .insights: return .insights
        }
    }
}

extension Route {
    var title: String {
        switch self {
        case .profile:       return one2String("one2.route.profile")
        case .settings:      return one2String("one2.route.settings")
        case .themeList:     return one2String("one2.route.themeList")
        case .templates:     return one2String("one2.route.templates")
        case .library:       return one2String("one2.route.library")
        case .theme:         return one2String("one2.route.theme")
        case .contentDetail: return one2String("one2.route.content")
        case .dayDetail:     return one2String("one2.route.day")
        case .entry:         return one2String("one2.route.entry")
        }
    }
}

extension CoverRoute {
    var title: String {
        switch self {
        case .checkIn:         return one2String("one2.route.checkIn")
        case .journalEditor:   return one2String("one2.route.journal")
        case .quoteReflection: return one2String("one2.route.quoteReflection")
        }
    }
}
