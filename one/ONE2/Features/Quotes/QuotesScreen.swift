//
//  QuotesScreen.swift
//  ONE 2.0
//
//  Sözler (ScreenSozler.preview.html). UX-3: iskelet; mod hapı ve
//  fırça/oynat/ara yüklenirken devre dışı. Akış UX-7'de gelir.
//

import SwiftUI

struct QuotesScreen: View {
    var body: some View {
        ScreenScaffold {
            ONE2Pill(one2String("one2.quotes.mode.forYou"), showsChevron: true) {}
                .disabled(true)
        } center: {
            EmptyView()
        } trailing: {
            ONE2RoundButton(icon: .brush, accessibilityLabel: one2String("one2.action.background")) {}
                .disabled(true)
            ONE2RoundButton(icon: .play, accessibilityLabel: one2String("one2.action.play")) {}
                .disabled(true)
            ONE2RoundButton(icon: .search, accessibilityLabel: one2String("one2.action.search")) {}
                .disabled(true)
        } content: {
            Skeleton {
                ONE2Radius.shape(ONE2Radius.xl)
                    .fill(ONE2Color.raised)
                    .frame(minHeight: ONE2Size.quoteCardMin)
            }
        }
    }
}

#if DEBUG
#Preview("Gece") { QuotesScreen().preferredColorScheme(.dark) }
#Preview("Gün") { QuotesScreen().preferredColorScheme(.light) }
#Preview("AX3") { QuotesScreen().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#endif
