//
//  WeekStrip.swift
//  ONE 2.0
//
//  Bugün'ün hafta şeridi (components/WeekStrip.md, `.o-week`): gün kısaltması
//  + tarih; tamamlanan günde tarih yerine tik.
//  - Tamam: `ink` tik. Yarım (sabah+akşam modunda biri): `ink-muted` tik.
//  - Bugün: 1px `line-strong` çerçeve, kalın. Seçili başka gün: `raised` zemin.
//  - Boş geçmiş gün: `ink-faint` tarih. Gelecek: `ink-faint`, dokunulamaz.
//  Yatay kaydırma önceki haftalar (sayfalı); seçim değişince seçili günün
//  haftasına döner.
//

import SwiftUI

struct WeekStrip: View {
    /// Eskiden yeniye; sonuncusu bu hafta.
    let weeks: [WeekStripData]
    let selected: DayKey
    let onSelect: (WeekDayState, WeekStripData) -> Void

    @State private var page: Int?

    private func weekIndex(of day: DayKey) -> Int? {
        weeks.firstIndex { $0.days.contains { $0.day == day } }
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                    WeekRow(week: week, selected: selected) { onSelect($0, week) }
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $page)
        .onAppear { page = weekIndex(of: selected) ?? weeks.count - 1 }
        .onChange(of: selected) { _, day in
            guard let index = weekIndex(of: day), index != page else { return }
            withAnimation(ONE2Motion.curve(.screen)) { page = index }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(one2String("one2.today.week.a11y")))
    }
}

private struct WeekRow: View {
    let week: WeekStripData
    let selected: DayKey
    let onSelect: (WeekDayState) -> Void

    var body: some View {
        HStack(spacing: ONE2Size.weekCellGap) {
            ForEach(week.days) { day in
                WeekCell(day: day, isSelected: day.day == selected) { onSelect(day) }
            }
        }
    }
}

private struct WeekCell: View {
    let day: WeekDayState
    let isSelected: Bool
    let action: () -> Void

    private var isToday: Bool { day.position == .today }
    private var isFuture: Bool { day.position == .future }

    var body: some View {
        Button(action: action) {
            VStack(spacing: ONE2Space.s1) {
                Text(one2String("one2.weekday.short.\(day.weekday)"))
                    .one2Type(isToday ? .headline : .bodySm)
                    .foregroundStyle(isToday ? ONE2Color.ink : (isFuture ? ONE2Color.inkFaint : ONE2Color.inkMuted))
                glyph
                    .frame(height: ONE2Size.weekGlyph)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: ONE2Size.weekCell)
            .background(isSelected && !isToday ? ONE2Color.raised : .clear, in: ONE2Radius.shape(ONE2Radius.md))
            .overlay {
                if isToday {
                    ONE2Radius.shape(ONE2Radius.md)
                        .strokeBorder(ONE2Color.lineStrong, lineWidth: ONE2Size.hairline)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.one2Press)
        .disabled(isFuture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var glyph: some View {
        switch day.completion {
        case .done where !isFuture:
            ONE2Icon.check.image().foregroundStyle(ONE2Color.ink)
        case .half where !isFuture:
            ONE2Icon.check.image().foregroundStyle(ONE2Color.inkMuted)
        default:
            Text(verbatim: "\(day.dayOfMonth)")
                .one2Type(.headline)
                .foregroundStyle(day.kind == .gap || isFuture ? ONE2Color.inkFaint : ONE2Color.ink)
        }
    }

    private var accessibilityText: String {
        var parts = ["\(one2String("one2.weekday.long.\(day.weekday)")) \(day.dayOfMonth)"]
        if isToday { parts.append(one2String("one2.today.week.today")) }
        switch day.completion {
        case .done: parts.append(one2String("one2.today.week.done"))
        case .half: parts.append(one2String("one2.today.week.half"))
        case .none where day.position == .past: parts.append(one2String("one2.today.week.gap"))
        case .none: break
        }
        return parts.joined(separator: ", ")
    }
}

extension WeekDayState {
    /// Ayın günü (`yyyy-MM-dd`'nin son iki hanesi).
    var dayOfMonth: Int { Int(day.string.suffix(2)) ?? 0 }
}

#if DEBUG
private struct WeekStripSample: View {
    @State private var selected = FixtureClock.today

    var body: some View {
        WeekStrip(weeks: TodayFixture.weeks, selected: selected) { day, _ in selected = day.day }
    }
}

#Preview("Gece") { WeekStripSample().one2Preview(.gece) }
#Preview("Gün") { WeekStripSample().one2Preview(.gun) }
#Preview("AX3") { WeekStripSample().one2Preview(.ax3) }
#endif
