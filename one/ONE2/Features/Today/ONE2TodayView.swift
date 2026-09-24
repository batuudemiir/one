//
//  ONE2TodayView.swift
//  ONE 2.0
//
//  Bugün ekranı (06_giris_akislari.md › Bugün ekranı), view data ile.
//  Yukarıdan aşağı: üst çubuk → hafta şeridi → ritüel alanı → Pratiklerin
//  → Haftalık tema → dock boşluğu. Akışlar `flowProvider`'dan gelir ve
//  tam ekran açılır. Motor bağlaması UX-11'de.
//

import SwiftUI

struct TodayActions {
    /// Doldurma sheet'inde "Doldur": o gün için akış.
    var fillDay: (WeekDayViewData) -> Void = { _ in }
    var openPractice: (PracticeTileViewData) -> Void = { _ in }
    var addPractice: () -> Void = {}
    var openTheme: () -> Void = {}
    var openProfile: () -> Void = {}
    /// Ritüel kartı: "Başla", "Devam et", "Yine de yap". `flowProvider`
    /// verilmişse akış tam ekran burada açılır; verilmemişse bu çağrılır.
    var startFlow: (FlowKind) -> Void = { _ in }
    var flowProvider: ((FlowKind) -> FlowViewModel)?
}

struct ONE2TodayView: View {
    let state: TodayViewState
    var actions = TodayActions()

    @State private var backfillDay: WeekDayViewData?
    @State private var presentedFlow: FlowPresentation?

    /// Yüzen dock'un altında kalmasın diye son öğeden sonraki boşluk.
    static let dockInset: CGFloat = V3Tokens.spacingXL5 * 2

    var body: some View {
        VStack(spacing: 0) {
            switch state {
            case .loading:
                TodayTopBar(streak: nil, greeting: "", onProfile: actions.openProfile)
                TodaySkeleton()
            case .loaded(let data):
                TodayTopBar(streak: data.streak, greeting: TodayRules.greeting(hour: data.hour),
                            onProfile: actions.openProfile)
                content(data)
            }
        }
        .oneScreenGround()
        .sheet(item: $backfillDay) { day in
            BackfillSheet(day: day, onFill: {
                backfillDay = nil
                actions.fillDay(day)
            }, onClose: { backfillDay = nil })
            .presentationDetents([.medium])
        }
        .fullScreenCover(item: $presentedFlow) { presentation in
            FlowShellView(model: presentation.model, onDismiss: { presentedFlow = nil })
        }
    }

    private func start(_ flow: FlowKind) {
        if let provider = actions.flowProvider {
            presentedFlow = FlowPresentation(model: provider(flow))
        } else {
            actions.startFlow(flow)
        }
    }

    private func content(_ data: TodayViewData) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: V3Tokens.spacingXL3) {
                WeekStripView(days: data.week, onBackfill: { backfillDay = $0 })
                RitualArea(layout: data.layout, cards: data.rituals, onStart: start)
                PracticesSection(practices: data.practices, onOpen: actions.openPractice, onAdd: actions.addPractice)
                if let theme = data.theme {
                    WeeklyThemeSection(theme: theme, onOpen: actions.openTheme)
                }
            }
            .padding(.top, V3Tokens.spacingLG)
            .padding(.bottom, Self.dockInset)
            .oneScreenBody()
        }
    }
}

// MARK: - Pratiklerin

struct PracticesSection: View {
    let practices: [PracticeTileViewData]
    let onOpen: (PracticeTileViewData) -> Void
    let onAdd: () -> Void

    private let columns = [GridItem(.flexible(), spacing: V3Tokens.spacingMD),
                           GridItem(.flexible(), spacing: V3Tokens.spacingMD)]

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
            Text(NSLocalizedString("one2.practices.title", comment: "Section: your practices"))
                .displayMD()
                .foregroundColor(V3Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: columns, spacing: V3Tokens.spacingMD) {
                ForEach(practices) { practice in
                    Button { onOpen(practice) } label: {
                        PracticeTileView(title: practice.title, symbol: practice.symbol, isAdd: false)
                    }
                    .buttonStyle(.onePressable)
                }
                Button(action: onAdd) {
                    PracticeTileView(title: NSLocalizedString("one2.practices.add", comment: "Add a practice"),
                                     symbol: "plus", isAdd: true)
                }
                .buttonStyle(.onePressable)
            }
        }
    }
}

/// PracticeTile: ortada ikon kuyusu, altında ad. "+ Ekle" şeffaf, çerçeveli.
struct PracticeTileView: View {
    let title: String
    let symbol: String
    let isAdd: Bool

    static let wellSize: CGFloat = 72

    var body: some View {
        VStack(spacing: V3Tokens.spacingMD) {
            Image(systemName: symbol)
                .iconLG()
                .foregroundColor(V3Tokens.ink)
                .frame(width: Self.wellSize, height: Self.wellSize)
                .background(Circle().fill(V3Tokens.wash))
                .accessibilityHidden(true)
            Text(title)
                .displayXS()
                .foregroundColor(V3Tokens.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(V3Tokens.spacingLG)
        .frame(maxWidth: .infinity, minHeight: Self.wellSize * 2)
        .modifier(PracticeTileBackground(isAdd: isAdd))
        .contentShape(Rectangle())
    }
}

private struct PracticeTileBackground: ViewModifier {
    let isAdd: Bool

    func body(content: Content) -> some View {
        if isAdd {
            content.overlay(
                RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous)
                    .strokeBorder(V3Tokens.hairline, lineWidth: 1)
            )
        } else {
            content.oneCardBackground(radius: V3Tokens.radiusTile)
        }
    }
}

// MARK: - Haftalık tema

struct WeeklyThemeSection: View {
    let theme: WeeklyThemeViewData
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
            Text(NSLocalizedString("one2.theme.title", comment: "Section: weekly theme"))
                .displayMD()
                .foregroundColor(V3Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
                Text(String.localizedStringWithFormat(
                    NSLocalizedString("one2.theme.label", comment: "Weekly theme · day x/7"), theme.dayIndex))
                    .v3MicroLabel()
                    .foregroundColor(V3Tokens.mutedText)
                Text(theme.name)
                    .displayMD()
                    .foregroundColor(V3Tokens.ink)
                Text(theme.prompt)
                    .font(V3Typography.quote(20))
                    .foregroundColor(V3Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ThemeDaysLine(opened: theme.dayIndex)
                if let firstLine = theme.writtenFirstLine {
                    Text(firstLine)
                        .font(V3Typography.journal(16))
                        .foregroundColor(V3Tokens.mutedText)
                        .lineLimit(1)
                }
                V3PrimaryButton(title: theme.writtenFirstLine == nil
                                ? NSLocalizedString("one2.theme.write", comment: "Write the weekly theme question")
                                : NSLocalizedString("one2.theme.continue", comment: "Continue the weekly theme entry"),
                                isFullWidth: true, action: onOpen)
            }
            .padding(V3Tokens.spacingXL)
            .oneCardBackground(radius: V3Tokens.radiusTile)
        }
    }
}

/// 7 çizgi: açılmış günler dolu, kilitli günler çerçeveli.
private struct ThemeDaysLine: View {
    let opened: Int

    var body: some View {
        HStack(spacing: V3Tokens.spacingXS) {
            ForEach(1...7, id: \.self) { day in
                if day <= opened {
                    Capsule(style: .continuous).fill(V3Tokens.ink)
                } else {
                    Capsule(style: .continuous).strokeBorder(V3Tokens.hairline, lineWidth: 1)
                }
            }
        }
        .frame(height: V3Tokens.spacingXS)
        .accessibilityHidden(true)
    }
}

// MARK: - Doldurma sheet'i

struct BackfillSheet: View {
    let day: WeekDayViewData
    let onFill: () -> Void
    let onClose: () -> Void

    var body: some View {
        V3SheetScreen(title: day.longLabel, onClose: onClose) {
            VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
                Text(RitualCopy.backfillMessage(day))
                    .bodyLG()
                    .foregroundColor(V3Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                V3PrimaryButton(title: NSLocalizedString("one2.backfill.action", comment: "Fill this day"),
                                isFullWidth: true, action: onFill)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Yükleniyor

/// States.md: iskelet çubukları, spinner yok.
struct TodaySkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL3) {
            bar(height: V3Tokens.spacingXL5)
            bar(height: RitualCardView.minHeight)
            bar(height: PracticeTileView.wellSize * 2)
        }
        .padding(.top, V3Tokens.spacingLG)
        .oneScreenBody()
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NSLocalizedString("general.loading", comment: "Loading"))
    }

    private func bar(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous)
            .fill(V3Tokens.wash)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .v3Shimmer(cornerRadius: V3Tokens.radiusTile)
    }
}

// MARK: - Önizlemeler

#Preview("Daily · not started") {
    ONE2TodayView(state: .loaded(TodayFixtures.dailyNotStarted()),
              actions: TodayActions(flowProvider: { FlowFixtureModels.model($0) }))
}

#Preview("Morning+evening · morning done") {
    ONE2TodayView(state: .loaded(TodayFixtures.morningDone()),
              actions: TodayActions(flowProvider: { FlowFixtureModels.model($0) }))
}

#Preview("Morning+evening · both done") {
    ONE2TodayView(state: .loaded(TodayFixtures.bothDone()))
}

#Preview("Loading") {
    ONE2TodayView(state: .loading)
}

#Preview("Morning missed · light") {
    ONE2TodayView(state: .loaded(TodayFixtures.morningMissed()))
        .preferredColorScheme(.light)
}

#Preview("Daily · in progress · AX3") {
    ONE2TodayView(state: .loaded(TodayFixtures.dailyInProgress()))
        .dynamicTypeSize(.accessibility3)
}
