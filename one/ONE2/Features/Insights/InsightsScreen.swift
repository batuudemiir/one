//
//  InsightsScreen.swift
//  ONE 2.0
//
//  Eğilimler (ScreenEgilimler.preview.html). UX-3: iskelet; "GENEL
//  İÇGÖRÜLER" altında mood çizgisi ve duygu dağılımı kartları. Dönem hapı
//  yüklenirken devre dışı. Kartlar UX-9'da.
//

import SwiftUI

struct InsightsScreen: View {
    var body: some View {
        ScreenScaffold(title: one2String("one2.screen.insights")) {
            EmptyView()
        } center: {
            EmptyView()
        } trailing: {
            ONE2Pill(one2String("one2.insights.period.days14"), showsChevron: true) {}
                .disabled(true)
        } content: {
            VStack(spacing: ONE2Space.cardGap) {
                ONE2Label(one2String("one2.insights.general"))
                    .frame(maxWidth: .infinity)
                Skeleton {
                    VStack(spacing: ONE2Space.cardGap) {
                        ONE2Card {
                            VStack(alignment: .leading, spacing: ONE2Space.s3) {
                                HStack {
                                    SkeletonBar(width: ONE2Size.skeletonPill, height: ONE2Size.tabIcon)
                                    Spacer()
                                    SkeletonBar(width: ONE2Size.skeletonPill / 2)
                                }
                                SkeletonBar(width: ONE2Size.skeletonPill)
                                ONE2Radius.shape(ONE2Radius.sm)
                                    .fill(ONE2Color.raised)
                                    .frame(height: ONE2Size.chartHeight)
                            }
                        }
                        ONE2Card {
                            VStack(alignment: .leading, spacing: ONE2Space.s3) {
                                SkeletonBar(width: ONE2Size.skeletonPill * 1.5, height: ONE2Size.tabIcon)
                                ForEach(0..<4, id: \.self) { _ in
                                    SkeletonBar(height: ONE2Space.s2 + ONE2Size.focusRing)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Gece") { InsightsScreen().preferredColorScheme(.dark) }
#Preview("Gün") { InsightsScreen().preferredColorScheme(.light) }
#Preview("AX3") { InsightsScreen().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#endif
