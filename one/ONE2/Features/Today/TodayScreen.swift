//
//  TodayScreen.swift
//  ONE 2.0
//
//  Bugün (ScreenBugun.preview.html): seri hapı · selamlama · profil →
//  hafta şeridi → check-in kartı → Pratiklerin → Haftalık tema.
//  Hafta şeridinde başka bir güne dokununca ekran o günü gösterir; üst
//  çubuğun ortasında "Bugüne dön" hapı çıkar, pratikler ve tema yalnız
//  bugünde. Boş geçmiş güne dokunmak (son 7 gün) doldurma sayfasını açar.
//  Veri `TodaySource`'tan: UX-4'te fixture, UX-11'de motorlar.
//

import SwiftUI

struct TodayScreen: View {
    let clock: any AppClock
    let source: TodaySource

    @Environment(Router.self) private var router
    /// `nil`: bugün.
    @State private var selectedDay: DayKey?
    @State private var backfillDay: WeekDayState?
    /// Uzun basmayla değişen yerel sıra (UX-11'de kalıcı sıra motorda).
    @State private var practiceOrder: [PracticeTileData]?

    private var shownDay: DayKey { selectedDay ?? source.today }
    private var isToday: Bool { shownDay == source.today }
    private var state: Loadable<TodayData> { source.day(shownDay) }

    private var shownWeekDay: WeekDayState? {
        source.weeks.lazy.flatMap(\.days).first { $0.day == shownDay }
    }

    var body: some View {
        ScreenScaffold {
            leading
        } center: {
            center
        } trailing: {
            ONE2RoundButton(icon: .profile, accessibilityLabel: one2String("one2.action.profile")) {
                router.push(.profile, on: .today)
            }
        } content: {
            VStack(alignment: .leading, spacing: ONE2Space.sectionGap) {
                VStack(spacing: ONE2Space.s5) {
                    if source.isOffline { OfflineBanner() }
                    if router.notice == .circleUnavailable {
                        NoticeCard(text: one2String("one2.notice.circleUnavailable")) { router.notice = nil }
                    }
                    WeekStrip(weeks: source.weeks, selected: shownDay, onSelect: select)
                    switch state {
                    case .loading:
                        CheckInSkeleton()
                    case .failed:
                        ErrorLine(
                            title: one2String("one2.today.error.title"),
                            message: one2String("one2.today.error.message")
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    case .loaded(let data):
                        CheckInPager(
                            cards: data.checkIns,
                            canCheckIn: canCheckIn,
                            isPast: !isToday,
                            onScore: { _, _ in router.cover = .checkIn },
                            onOpen: { _ in router.push(.dayDetail(shownDay), on: .today) }
                        )
                    }
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
                onFill: {
                    backfillDay = nil
                    router.cover = .checkIn
                },
                onDismiss: { backfillDay = nil }
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
        case .loaded(let data) where data.streak.isVisible:
            StreakPill(count: data.streak.current)
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var center: some View {
        if isToday {
            Text(Greeting.at(clock.now, calendar: clock.calendar).text)
                .one2Type(.greeting)
                .foregroundStyle(ONE2Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
        } else {
            ONE2Pill(one2String("one2.today.backToToday")) {
                ONE2Haptics.selection()
                selectedDay = nil
            }
        }
    }

    // MARK: - Bölümler

    private func practices(_ data: TodayData) -> some View {
        let list = practiceOrder ?? data.practices
        return VStack(alignment: .leading, spacing: ONE2Space.s3) {
            SectionHeader(title: one2String("one2.today.practices"))
            PracticeGrid(
                practices: list,
                onOpen: { router.push(.contentDetail($0.contentID), on: .today) },
                onAdd: { router.push(.library, on: .today) },
                onMove: { item, move in
                    withAnimation(ONE2Motion.curve(.chip)) {
                        practiceOrder = move.apply(to: list, id: item.id)
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

    /// Boş kartta skor ölçeği: bugün ya da doldurma penceresindeki gün.
    private var canCheckIn: Bool {
        guard !isToday else { return true }
        guard let day = shownWeekDay,
              let week = source.weeks.first(where: { $0.days.contains(day) }) else { return false }
        return week.canBackfill(day)
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

private struct CheckInSkeleton: View {
    var body: some View {
        Skeleton {
            ONE2OutlineCard(minHeight: ONE2Size.checkInCardMin) {
                VStack(spacing: ONE2Space.s8) {
                    SkeletonLines(count: 2)
                    Capsule().fill(ONE2Color.raised)
                        .frame(width: ONE2Size.skeletonPill * 1.5, height: ONE2Size.minTouch)
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
private func todayPreview(_ source: TodaySource) -> some View {
    TodayScreen(clock: FixtureClock.clock, source: source).environment(Router())
}

#Preview("Gece · check-in var") { todayPreview(TodayFixture.source(TodayFixture.many)).preferredColorScheme(.dark) }
#Preview("Gün · check-in yok") { todayPreview(TodayFixture.source(TodayFixture.few)).preferredColorScheme(.light) }
#Preview("AX3") {
    todayPreview(TodayFixture.source(TodayFixture.many))
        .preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#Preview("Sabah + akşam") { todayPreview(TodayFixture.source(TodayFixture.morningEvening)).preferredColorScheme(.dark) }
#Preview("İlk gün") { todayPreview(TodayFixture.source(TodayFixture.empty)).preferredColorScheme(.dark) }
#Preview("Seri gizli") { todayPreview(TodayFixture.source(TodayFixture.streakHidden)).preferredColorScheme(.dark) }
#Preview("Çevrimdışı") { todayPreview(TodayFixture.source(TodayFixture.many, isOffline: true)).preferredColorScheme(.dark) }
#Preview("Yükleniyor") { todayPreview(TodayFixture.loading).preferredColorScheme(.dark) }
#Preview("Hata") { todayPreview(TodayFixture.failed).preferredColorScheme(.light) }
#endif
