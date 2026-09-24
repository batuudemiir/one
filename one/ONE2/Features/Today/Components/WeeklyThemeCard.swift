//
//  WeeklyThemeCard.swift
//  ONE 2.0
//
//  Haftalık temanın bugünkü sorusu (07 §5.1; components/WeeklyThemeCard.md
//  zemini): mono label "HAFTALIK TEMA · GÜN 4/7", tema adı `title`, soru
//  Literata `prompt`, `Yaz` ikincil hap (ekranın birincil eylemi ritüel
//  kartında). Yazıldıysa ilk satır + "Devam et". Kartın altında 7 nokta:
//  açılmış günler dolu, gelecek günler kilitli (boş halka).
//

import SwiftUI

struct WeeklyThemeCard: View {
    let theme: ThemeCardData
    let onWrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s4) {
            ONE2Label(String(format: one2String("one2.today.theme.label"), theme.day, 7))
            Text(theme.name)
                .one2Type(.title)
                .foregroundStyle(ONE2Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text(theme.question)
                .one2Type(.prompt)
                .foregroundStyle(ONE2Color.ink)
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
            .buttonStyle(.one2(.secondary))
            dayDots
                .padding(.top, ONE2Space.s1)
        }
        .padding(.top, ONE2Space.s6)
        .padding([.horizontal, .bottom], ONE2Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ONE2Color.surface, in: ONE2Radius.shape(ONE2Radius.lg))
    }

    private var dayDots: some View {
        HStack(spacing: ONE2Size.themeDotGap) {
            ForEach(1...7, id: \.self) { day in
                Group {
                    if day <= theme.unlockedDays {
                        Circle().fill(ONE2Color.ink)
                    } else {
                        Circle().strokeBorder(ONE2Color.lineStrong, lineWidth: ONE2Size.hairline)
                    }
                }
                .frame(width: ONE2Size.themeDot, height: ONE2Size.themeDot)
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
