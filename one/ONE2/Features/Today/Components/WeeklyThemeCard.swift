//
//  WeeklyThemeCard.swift
//  ONE 2.0
//
//  Haftalık temanın bugünkü sorusu (components/WeeklyThemeCard.md,
//  `.o-theme`): `label` "HAFTALIK TEMA · 4/7", tema adı, soru (`prompt`
//  serif), 7 çizgi (açılmış gün `ink`, kilitli gün 1px `line` kenar), tam
//  genişlik `primary` "Yaz". Yazıldıysa "Devam et" + ilk satır.
//

import SwiftUI

struct WeeklyThemeCard: View {
    let theme: ThemeCardData
    let onWrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s4) {
            ONE2Label(String(format: one2String("one2.today.theme.label"), theme.day, 7))
            Text(theme.name)
                .one2Type(.greeting)
                .foregroundStyle(ONE2Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text(theme.question)
                .one2Type(.prompt)
                .foregroundStyle(ONE2Color.ink)
            dayBars
            if theme.isWritten, let firstLine = theme.firstLine {
                Text(firstLine)
                    .one2Type(.journal)
                    .foregroundStyle(ONE2Color.inkMuted)
                    .lineLimit(2)
            }
            Button(action: onWrite) {
                Text(one2String(theme.isWritten ? "one2.today.theme.continue" : "one2.today.theme.write"))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.one2(.primary, fullWidth: true))
        }
        .padding(.top, ONE2Space.s6)
        .padding([.horizontal, .bottom], ONE2Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ONE2Color.surface, in: ONE2Radius.shape(ONE2Radius.lg))
    }

    private var dayBars: some View {
        HStack(spacing: ONE2Size.themeBarGap) {
            ForEach(1...7, id: \.self) { day in
                let shape = Capsule()
                if day <= theme.unlockedDays {
                    shape.fill(ONE2Color.ink).frame(height: ONE2Size.themeBar)
                } else {
                    shape.strokeBorder(ONE2Color.line, lineWidth: ONE2Size.hairline).frame(height: ONE2Size.themeBar)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(format: one2String("one2.today.theme.days.a11y"), theme.unlockedDays, 7)))
    }
}

#if DEBUG
private struct WeeklyThemeCardSamples: View {
    var body: some View {
        VStack(spacing: ONE2Space.s5) {
            WeeklyThemeCard(theme: TodayFixture.theme) {}
            WeeklyThemeCard(theme: TodayFixture.themeWritten) {}
        }
    }
}

#Preview("Gece") { WeeklyThemeCardSamples().one2Preview(.gece) }
#Preview("Gün") { WeeklyThemeCardSamples().one2Preview(.gun) }
#Preview("AX3") { WeeklyThemeCardSamples().one2Preview(.ax3) }
#endif
