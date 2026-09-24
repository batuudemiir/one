//
//  TodayScreen.swift
//  ONE 2.0
//
//  Bugün (ScreenBugun.preview.html). UX-3: gerçek yerleşimde iskelet;
//  seri hapı → hafta şeridi → check-in kartı → Pratiklerin → Haftalık tema.
//  Veri UX-4'te fixture ile, UX-11'de motorlarla gelir.
//

import SwiftUI

struct TodayScreen: View {
    let clock: any AppClock

    @Environment(Router.self) private var router

    var body: some View {
        ScreenScaffold {
            Skeleton {
                Capsule().fill(ONE2Color.raised)
                    .frame(width: ONE2Size.skeletonPill, height: ONE2Size.control)
            }
        } center: {
            Text(Greeting.at(clock.now, calendar: clock.calendar).text)
                .one2Type(.greeting)
                .foregroundStyle(ONE2Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
        } trailing: {
            ONE2RoundButton(icon: .profile, accessibilityLabel: one2String("one2.action.profile")) {
                router.push(.profile, on: .today)
            }
        } content: {
            VStack(alignment: .leading, spacing: ONE2Space.sectionGap) {
                if router.notice == .circleUnavailable {
                    NoticeCard(text: one2String("one2.notice.circleUnavailable")) { router.notice = nil }
                }
                Skeleton {
                    VStack(spacing: ONE2Space.s5) {
                        HStack(spacing: ONE2Space.s1) {
                            ForEach(0..<7, id: \.self) { _ in
                                ONE2Radius.shape(ONE2Radius.md)
                                    .fill(ONE2Color.raised)
                                    .frame(height: ONE2Size.weekCell)
                            }
                        }
                        ONE2OutlineCard(minHeight: ONE2Size.checkInCardMin) {
                            VStack(spacing: ONE2Space.s8) {
                                SkeletonLines(count: 2)
                                Capsule().fill(ONE2Color.raised)
                                    .frame(width: ONE2Size.skeletonPill * 1.5, height: ONE2Size.minTouch)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: ONE2Space.s3) {
                    SectionHeader(title: one2String("one2.today.practices"))
                    Skeleton {
                        HStack(spacing: ONE2Space.cardGap) {
                            ForEach(0..<2, id: \.self) { _ in
                                ONE2Card(padding: ONE2Space.s5) {
                                    VStack(spacing: ONE2Space.s4) {
                                        Circle().fill(ONE2Color.raised)
                                            .frame(width: ONE2Size.iconWell, height: ONE2Size.iconWell)
                                        SkeletonBar(width: ONE2Size.skeletonPill)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: ONE2Size.practiceTileMin - 2 * ONE2Space.s5)
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: ONE2Space.s3) {
                    SectionHeader(title: one2String("one2.today.weeklyTheme"), trailing: .seeAll {
                        router.push(.themeList, on: .today)
                    })
                    Skeleton {
                        ONE2Card(padding: ONE2Space.s6) {
                            VStack(alignment: .leading, spacing: ONE2Space.s4) {
                                SkeletonBar(width: ONE2Size.skeletonPill)
                                SkeletonBar(width: ONE2Size.skeletonPill * 1.5, height: ONE2Size.icon)
                                SkeletonLines(count: 2)
                                Capsule().fill(ONE2Color.raised).frame(height: ONE2Size.button)
                            }
                        }
                    }
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
#Preview("Gece") { TodayScreen(clock: FixtureClock.clock).environment(Router()).preferredColorScheme(.dark) }
#Preview("Gün") { TodayScreen(clock: FixtureClock.clock).environment(Router()).preferredColorScheme(.light) }
#Preview("AX3") {
    TodayScreen(clock: FixtureClock.clock).environment(Router())
        .preferredColorScheme(.dark).dynamicTypeSize(.accessibility3)
}
#endif
