//
//  ExploreScreen.swift
//  ONE 2.0
//
//  Keşfet (ScreenKesfet.preview.html). UX-3: iskelet; öne çıkan kart ve
//  iki sütun içerik karosu. Ara yüklenirken devre dışı. İçerik UX-8'de.
//

import SwiftUI

struct ExploreScreen: View {
    var body: some View {
        ScreenScaffold(title: one2String("one2.screen.explore")) {
            EmptyView()
        } center: {
            EmptyView()
        } trailing: {
            ONE2RoundButton(icon: .search, accessibilityLabel: one2String("one2.action.search")) {}
                .disabled(true)
        } content: {
            Skeleton {
                VStack(spacing: ONE2Space.cardGap) {
                    HStack(spacing: 0) {
                        Rectangle().fill(ONE2Color.raised)
                            .frame(width: ONE2Size.iconWell * 2)
                        VStack(alignment: .leading, spacing: ONE2Space.s3) {
                            SkeletonBar(width: ONE2Size.skeletonPill)
                            SkeletonBar(height: ONE2Size.icon)
                            SkeletonLines(count: 3)
                            Spacer(minLength: 0)
                            Capsule().fill(ONE2Color.raised)
                                .frame(width: ONE2Size.skeletonPill, height: ONE2Size.buttonCompact)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.horizontal, ONE2Space.s4)
                        .padding(.vertical, ONE2Space.s5)
                    }
                    .frame(minHeight: ONE2Size.featuredMin)
                    .background(ONE2Color.surface)
                    .clipShape(ONE2Radius.shape(ONE2Radius.lg))

                    HStack(spacing: ONE2Space.cardGap) {
                        ForEach(0..<2, id: \.self) { _ in
                            ONE2Card(padding: ONE2Space.s4) {
                                VStack(spacing: ONE2Space.s2) {
                                    UnevenRoundedRectangle(
                                        topLeadingRadius: ONE2Size.contentArt / 2,
                                        topTrailingRadius: ONE2Size.contentArt / 2,
                                        style: .continuous
                                    )
                                    .fill(ONE2Color.raised)
                                    .frame(width: ONE2Size.contentArt, height: ONE2Size.contentArt)
                                    .padding(.bottom, ONE2Space.s3)
                                    SkeletonBar(width: ONE2Size.skeletonPill / 2)
                                    SkeletonBar(height: ONE2Size.icon)
                                    SkeletonLines(count: 2)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Gece") { ExploreScreen().preferredColorScheme(.dark) }
#Preview("Gün") { ExploreScreen().preferredColorScheme(.light) }
#Preview("AX3") { ExploreScreen().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#endif
