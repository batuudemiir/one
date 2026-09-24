//
//  JourneyScreen.swift
//  ONE 2.0
//
//  Yolculuk (ScreenYolculuk.preview.html). UX-3: iskelet; gün başlığı,
//  check-in kartı, fotoğraf anısı, günlük kartı. Dönem hapı, filtre ve
//  ara yüklenirken devre dışı. Akış UX-9'da.
//

import SwiftUI

struct JourneyScreen: View {
    var body: some View {
        ScreenScaffold(title: one2String("one2.screen.journey")) {
            EmptyView()
        } center: {
            EmptyView()
        } trailing: {
            ONE2Pill(one2String("one2.journey.period.days"), showsChevron: true) {}
                .disabled(true)
            ONE2RoundButton(icon: .filter, accessibilityLabel: one2String("one2.action.filter")) {}
                .disabled(true)
            ONE2RoundButton(icon: .search, accessibilityLabel: one2String("one2.action.search")) {}
                .disabled(true)
        } content: {
            Skeleton {
                VStack(alignment: .leading, spacing: ONE2Space.cardGap) {
                    SkeletonBar(width: ONE2Size.skeletonPill * 1.5, height: ONE2Size.tabIcon)
                        .padding(.horizontal, ONE2Space.s4)
                    ONE2Card {
                        VStack(alignment: .leading, spacing: ONE2Space.s3) {
                            HStack {
                                SkeletonBar(width: ONE2Size.skeletonPill * 1.5, height: ONE2Size.tabIcon)
                                Spacer()
                                SkeletonBar(width: ONE2Size.minTouch)
                            }
                            Capsule().fill(ONE2Color.raised)
                                .frame(width: ONE2Size.skeletonPill * 2, height: ONE2Size.minTouch)
                        }
                    }
                    ONE2Radius.shape(ONE2Radius.lg)
                        .fill(ONE2Color.raised)
                        .frame(height: ONE2Size.memoryMin)
                    ONE2Card {
                        VStack(alignment: .leading, spacing: ONE2Space.s3) {
                            SkeletonBar(width: ONE2Size.skeletonPill * 2, height: ONE2Size.tabIcon)
                            SkeletonLines(count: 3)
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Gece") { JourneyScreen().preferredColorScheme(.dark) }
#Preview("Gün") { JourneyScreen().preferredColorScheme(.light) }
#Preview("AX3") { JourneyScreen().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#endif
