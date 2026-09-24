//
//  TodayScreen.swift
//  ONE 2.0
//
//  Bugün (07 §5.1): seri hapı · selamlama · profil → hafta şeridi → geri
//  dönüş kartı → ritüel alanı → Pratiklerin → Haftalık tema.
//  Hafta şeridinde başka bir güne dokununca ekran o günü gösterir; üst
//  çubuğun ortasında "Bugüne dön" hapı çıkar, geri dönüş, pratikler ve tema
//  yalnız bugünde. Boş geçmiş güne dokunmak (son 7 gün) doldurma sayfasını
//  açar. `brand` yalnız seri sayısında. Veri `TodaySource`'tan: UX-4'te
//  fixture, UX-11'de motorlar.
//

import SwiftUI

struct TodayScreen: View {
    let clock: any AppClock
    let source: TodaySource

    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `nil`: bugün.
    @State private var selectedDay: DayKey?
    @State private var backfillDay: WeekDayState?
    /// Pratik sırası ve işaretleri (UX-11'de motorda kalıcı).
    @State private var practiceOverride: [PracticeTileData]?
    /// × ile bugün için gizlenen geri dönüş kartı (UX-11'de kalıcı).
    @State private var hiddenResurfaceID: String?
    @State private var reloadToken = 0

    init(clock: any AppClock, source: TodaySource, initialDay: DayKey? = nil) {
        self.clock = clock
        self.source = source
        _selectedDay = State(initialValue: initialDay == source.today ? nil : initialDay)
    }

    private var shownDay: DayKey { selectedDay ?? source.today }
    private var isToday: Bool { shownDay == source.today }

    private var state: Loadable<TodayData> {
        _ = reloadToken
        return source.day(shownDay)
    }

    private var todayData: TodayData? {
        if case .loaded(let data) = source.day(source.today) { return data }
        return nil
    }

    var body: some View {
        ScreenScaffold {
            leading
        } center: {
            center
        } trailing: {
            ProfileButton(name: todayData?.userName) { router.push(.profile, on: .today) }
        } content: {
            VStack(alignment: .leading, spacing: ONE2Space.sectionGap) {
                VStack(spacing: ONE2Space.s5) {
                    if source.isContentStale { OfflineBanner() }
                    if router.notice == .circleUnavailable {
                        NoticeCard(text: one2String("one2.notice.circleUnavailable")) { router.notice = nil }
                    }
                    WeekStrip(
                        weeks: source.weeks,
                        selected: shownDay,
                        onlyToday: todayData?.isFirstDay == true,
                        onSelect: select
                    )
                    dayContent
                }
                if isToday, case .loaded(let data) = state {
                    practices(data)
                    if let theme = data.theme {
                        themeSection(theme)
                    }
                }
            }
        }
        .sheet(item: $backfillDay) { day in
            BackfillSheet(
                day: day,
                today: source.today,
                onCheckIn: {
                    backfillDay = nil
                    router.cover = .flow(flow(for: day.day), day: day.day)
                },
                onWrite: {
                    backfillDay = nil
                    router.cover = .journalEditor(.blank)
                }
            )
        }
    }

    // MARK: - Üst çubuk

    @ViewBuilder private var leading: some View {
        switch state {
        case .loading:
            Skeleton {
                Capsule().fill(ONE2Color.raised)
                    .frame(width: ONE2Size.skeletonPill, height: ONE2Size.control)
            }
        case .loaded(let data) where data.streak.isVisible && !data.isFirstDay:
            StreakPill(count: data.streak.current)
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var center: some View {
        if isToday {
            VStack(spacing: 0) {
                Text(Greeting.at(clock.now, calendar: clock.calendar).text)
                    .one2Type(.greeting)
                    .foregroundStyle(ONE2Color.ink)
                    .accessibilityAddTraits(.isHeader)
                if let name = todayData?.userName {
                    Text(name)
                        .one2Type(.bodySm)
                        .foregroundStyle(ONE2Color.inkMuted)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            ONE2Pill(one2String("one2.today.backToToday")) {
                ONE2Haptics.selection()
                selectedDay = nil
            }
        }
    }

    // MARK: - Gün

    @ViewBuilder private var dayContent: some View {
        switch state {
        case .loading:
            CheckInSkeleton()
        case .failed:
            ErrorLine(
                title: one2String("one2.today.error.title"),
                message: one2String("one2.today.error.message"),
                retry: { reloadToken += 1 }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear { ONE2Haptics.error() }
        case .loaded(let data):
            VStack(spacing: ONE2Space.s5) {
                if isToday, let resurface = data.resurface, resurface.id != hiddenResurfaceID {
                    ResurfaceCard(
                        data: resurface,
                        onRewrite: { rewrite(resurface) },
                        onRead: { router.push(.entry(resurface.entryID), on: .today) },
                        onDismiss: {
                            withAnimation(ONE2Motion.animation(.screen, reduceMotion: reduceMotion)) {
                                hiddenResurfaceID = resurface.id
                            }
                        }
                    )
                    .transition(.opacity)
                }
                CheckInPager(
                    cards: ordered(data),
                    onStart: { card in
                        router.cover = .flow(card.flow, day: isToday ? nil : shownDay)
                    },
                    onOpen: { _ in router.push(.dayDetail(shownDay), on: .today) }
                )
            }
        }
    }

    /// Sabah+akşam modunda 05–14 arası sabah önde, sonrasında akşam önde.
    private func ordered(_ data: TodayData) -> [CheckInCardData] {
        guard data.mode == .morningEvening, isToday else { return data.checkIns }
        let hour = clock.calendar.component(.hour, from: clock.now)
        let morningFirst = (5..<14).contains(hour)
        return data.checkIns.sorted { a, _ in (a.slot == .morning) == morningFirst }
    }

    private func rewrite(_ resurface: ResurfaceCardData) {
        if let quoteID = resurface.quoteID {
            router.cover = .quoteReflection(quoteID: quoteID)
        } else if let promptID = resurface.promptID {
            router.cover = .journalEditor(.prompt(promptID))
        } else {
            router.push(.entry(resurface.entryID), on: .today)
        }
    }

    // MARK: - Bölümler

    private func practices(_ data: TodayData) -> some View {
        let list = practiceOverride ?? data.practices
        return VStack(alignment: .leading, spacing: ONE2Space.s3) {
            SectionHeader(title: one2String("one2.today.practices"))
            PracticeGrid(
                practices: list,
                onToggle: { item in
                    ONE2Haptics.light()
                    practiceOverride = list.map { $0.id == item.id ? $0.toggled() : $0 }
                },
                onAdd: { router.push(.library, on: .today) },
                onMove: { item, move in
                    withAnimation(ONE2Motion.animation(.chip, reduceMotion: reduceMotion)) {
                        practiceOverride = move.apply(to: list, id: item.id)
                    }
                }
            )
        }
    }

    private func themeSection(_ theme: ThemeCardData) -> some View {
        VStack(alignment: .leading, spacing: ONE2Space.s3) {
            SectionHeader(title: one2String("one2.today.weeklyTheme"), trailing: .seeAll {
                router.push(.themeList, on: .today)
            })
            WeeklyThemeCard(theme: theme) {
                router.cover = .journalEditor(.weeklyTheme(themeID: theme.id, day: theme.day))
            }
        }
    }

    // MARK: - Hafta şeridi

    /// Doldurulacak günün akışı: o günün ilk ritüel kartı.
    private func flow(for day: DayKey) -> FlowKind {
        if case .loaded(let data) = source.day(day), let first = data.checkIns.first { return first.flow }
        return .dailyCheckIn
    }

    private func select(_ day: WeekDayState, in week: WeekStripData) {
        ONE2Haptics.selection()
        selectedDay = day.day == source.today ? nil : day.day
        if week.canBackfill(day) {
            backfillDay = day
        }
    }
}

// MARK: - Parçalar

/// Profil yuvarlağı: ad baş harfi ya da ikon (07 §4.1).
private struct ProfileButton: View {
    let name: String?
    let action: () -> Void

    var body: some View {
        if let initial = name?.first.map({ ONE2Type.uppercased(String($0)) }) {
            Button(action: action) {
                Text(initial)
                    .one2Type(.headline)
                    .foregroundStyle(ONE2Color.ink)
                    .frame(width: ONE2Size.control, height: ONE2Size.control)
                    .background(ONE2Color.raised, in: Circle())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.one2Press)
            .accessibilityLabel(Text(one2String("one2.action.profile")))
        } else {
            ONE2RoundButton(icon: .profile, accessibilityLabel: one2String("one2.action.profile"), action: action)
        }
    }
}

private struct CheckInSkeleton: View {
    var body: some View {
        Skeleton {
            ONE2OutlineCard(minHeight: ONE2Size.checkInCardMin) {
                VStack(spacing: ONE2Space.s6) {
                    SkeletonLines(count: 2)
                    Capsule().fill(ONE2Color.raised)
                        .frame(width: ONE2Size.skeletonPill, height: ONE2Size.button)
                }
            }
        }
    }
}

/// Kabuktan gelen tek seferlik bilgi (ör. eski Çevre linki).
private struct NoticeCard: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        ONE2Card(padding: ONE2Space.s4) {
            HStack(alignment: .center, spacing: ONE2Space.s3) {
                Text(text)
                    .one2Type(.bodySm)
                    .foregroundStyle(ONE2Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ONE2RoundButton(icon: .close, accessibilityLabel: one2String("one2.action.close"), filled: false, action: onDismiss)
            }
        }
    }
}

#if DEBUG
private func todayPreview(_ source: TodaySource, day: DayKey? = nil, clock: any AppClock = FixtureClock.clock) -> some View {
    TodayScreen(clock: clock, source: source, initialDay: day).environment(Router())
}

private let morningClock = FixedClock(FixtureClock.date(2026, 9, 24, 9, 30), timeZone: FixtureClock.timeZone)

// Ana görünüm: gece, gün, AX3.
#Preview("Gece") { todayPreview(TodayFixture.source(TodayFixture.done)).preferredColorScheme(.dark) }
#Preview("Gün") { todayPreview(TodayFixture.source(TodayFixture.done)).preferredColorScheme(.light) }
#Preview("AX3") { todayPreview(TodayFixture.source(TodayFixture.done)).preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }

// Ritüel kartı durumları (07 §5.1).
#Preview("Başlamadı") { todayPreview(TodayFixture.source(TodayFixture.notStarted)).preferredColorScheme(.dark) }
#Preview("Yarıda") { todayPreview(TodayFixture.source(TodayFixture.inProgress)).preferredColorScheme(.dark) }
#Preview("Sabah + akşam, akşam önde") { todayPreview(TodayFixture.source(TodayFixture.morningEvening)).preferredColorScheme(.dark) }
#Preview("Sabah + akşam, sabah önde") {
    todayPreview(TodayFixture.source(TodayFixture.morningEvening), clock: morningClock).preferredColorScheme(.light)
}
#Preview("Sabah kaçırıldı") { todayPreview(TodayFixture.source(TodayFixture.morningMissed)).preferredColorScheme(.dark) }

// Ekran durumları (07 §5.1, §6).
#Preview("Boş · ilk gün") { todayPreview(TodayFixture.source(TodayFixture.firstDay)).preferredColorScheme(.dark) }
#Preview("Seri gizli") { todayPreview(TodayFixture.source(TodayFixture.streakHidden)).preferredColorScheme(.dark) }
#Preview("Geçmiş gün · dolu") {
    todayPreview(TodayFixture.source(TodayFixture.done), day: FixtureClock.today.adding(days: -3)).preferredColorScheme(.dark)
}
#Preview("Geçmiş gün · doldurulabilir") {
    todayPreview(TodayFixture.source(TodayFixture.done), day: FixtureClock.today.adding(days: -1)).preferredColorScheme(.light)
}
#Preview("Geçmiş gün · 7 günden eski") {
    todayPreview(TodayFixture.source(TodayFixture.done), day: FixtureClock.today.adding(days: -9)).preferredColorScheme(.dark)
}
#Preview("Yükleniyor") { todayPreview(TodayFixture.loading).preferredColorScheme(.dark) }
#Preview("Hata") { todayPreview(TodayFixture.failed).preferredColorScheme(.light) }
#Preview("Çevrimdışı · içerik eski") {
    todayPreview(TodayFixture.source(TodayFixture.done, isContentStale: true)).preferredColorScheme(.dark)
}
#endif
