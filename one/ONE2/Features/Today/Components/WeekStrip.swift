//
//  WeekStrip.swift
//  ONE 2.0
//
//  Bugün'ün hafta şeridi (07 §5.1): gün kısaltması + gün işareti.
//  - `done`: dolu `ink` disk + tik. `half`: yarım disk.
//  - `gap`: kesikli halka. `future`: soluk tarih, dokunulamaz.
//  - `today`: `line-strong` kutu; içinde tarih ya da (tamamsa) disk.
//  - Seçili başka gün: `raised` zemin.
//  - İlk gün: yalnız bugün; diğer hücreler boş ve dokunulamaz.
//  Yatay kaydırma önceki haftalar (sayfalı); seçim değişince seçili günün
//  haftasına döner.
//

import SwiftUI

struct WeekStrip: View {
    /// Eskiden yeniye; sonuncusu bu hafta.
    let weeks: [WeekStripData]
    let selected: DayKey
    /// İlk gün: yalnız bugünün hücresi.
    var onlyToday = false
    let onSelect: (WeekDayState, WeekStripData) -> Void

    @State private var page: Int?

    private var shownWeeks: [WeekStripData] {
        onlyToday ? Array(weeks.suffix(1)) : weeks
    }

    private func weekIndex(of day: DayKey) -> Int? {
        shownWeeks.firstIndex { $0.days.contains { $0.day == day } }
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(shownWeeks.enumerated()), id: \.offset) { index, week in
                    WeekRow(week: week, selected: selected, onlyToday: onlyToday) { onSelect($0, week) }
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $page)
        .onAppear { page = weekIndex(of: selected) ?? shownWeeks.count - 1 }
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
    let onlyToday: Bool
    let onSelect: (WeekDayState) -> Void

    var body: some View {
        HStack(spacing: ONE2Size.weekCellGap) {
            ForEach(week.days) { day in
                WeekCell(
                    day: day,
                    isSelected: day.day == selected,
                    isHidden: onlyToday && day.position != .today
                ) { onSelect(day) }
            }
        }
    }
}

private struct WeekCell: View {
    let day: WeekDayState
    let isSelected: Bool
    /// İlk gün: bugün dışındaki hücreler yalnız gün adıyla, soluk.
    let isHidden: Bool
    let action: () -> Void

    private var isToday: Bool { day.position == .today }
    private var isFuture: Bool { day.position == .future }
    private var isFaint: Bool { isFuture || isHidden }

    var body: some View {
        Button(action: action) {
            VStack(spacing: ONE2Space.s1) {
                Text(one2String("one2.weekday.short.\(day.weekday)"))
                    .one2Type(isToday ? .headline : .bodySm)
                    .foregroundStyle(isToday ? ONE2Color.ink : (isFaint ? ONE2Color.inkFaint : ONE2Color.inkMuted))
                Group {
                    if isHidden { Color.clear } else { glyph }
                }
                .frame(width: ONE2Size.weekGlyph, height: ONE2Size.weekGlyph)
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
        .disabled(isFaint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var glyph: some View {
        switch day.completion {
        case .done where !isFuture:
            ZStack {
                Circle().fill(ONE2Color.ink)
                ONE2Icon.check.image(size: ONE2Size.weekTick)
                    .fontWeight(.semibold)
                    .foregroundStyle(ONE2Color.ground)
            }
        case .half where !isFuture:
            ZStack {
                Circle().strokeBorder(ONE2Color.ink, lineWidth: ONE2Size.hairline)
                Circle().fill(ONE2Color.ink)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: ONE2Size.weekGlyph / 2)
                    }
            }
        default:
            if day.kind == .gap {
                Circle()
                    .strokeBorder(ONE2Color.inkMuted, style: StrokeStyle(lineWidth: ONE2Size.hairline, dash: [ONE2Size.weekDash]))
            } else {
                Text(verbatim: "\(day.dayOfMonth)")
                    .one2Type(.headline)
                    .foregroundStyle(isFuture ? ONE2Color.inkFaint : ONE2Color.ink)
                    .fixedSize()
            }
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
    var onlyToday = false
    @State private var selected = FixtureClock.today

    var body: some View {
        WeekStrip(weeks: TodayFixture.weeks, selected: selected, onlyToday: onlyToday) { day, _ in selected = day.day }
    }
}

#Preview("Gece") { WeekStripSample().one2Preview(.gece) }
#Preview("Gün") { WeekStripSample().one2Preview(.gun) }
#Preview("AX3") { WeekStripSample().one2Preview(.ax3) }
#Preview("İlk gün") { WeekStripSample(onlyToday: true).one2Preview(.gece) }
#endif
