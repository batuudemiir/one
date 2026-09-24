//
//  WeekStripView.swift
//  ONE 2.0
//
//  Hafta şeridi (WeekStrip.md): gün kısaltması + tarih; kapanan günde
//  tarih yerine tik, bugün çerçeveli. Kapanışta (`revealToday`) bugünün
//  hücresi ekranda tike döner. Geriye dönük doldurma akışı gelene kadar
//  hücreler dokunulamaz.
//

import SwiftUI

struct WeekStripView: View {
    let cells: [WeekDayCell]
    var revealToday = false

    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(cells) { cell in
                column(cell)
                    .frame(maxWidth: .infinity)
            }
        }
        .task {
            guard revealToday, !revealed else { return }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(reduceMotion ? nil : ONEAnimation.easingSaved) { revealed = true }
        }
    }

    private func state(_ cell: WeekDayCell) -> WeekDayState {
        revealToday && cell.isToday && !revealed ? .open : cell.state
    }

    private func column(_ cell: WeekDayCell) -> some View {
        VStack(spacing: V3Tokens.spacingXS) {
            Text(Calendar.current.shortStandaloneWeekdaySymbols[WeekStripModel.symbolIndex(for: cell.day)])
                .v3MicroLabel(0.4)
                .foregroundColor(V3Tokens.mutedText)
            mark(cell)
                .frame(width: V3Tokens.minTouchTarget, height: V3Tokens.minTouchTarget)
                .overlay {
                    if cell.isToday {
                        RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                            .strokeBorder(V3Tokens.ink, lineWidth: 1)
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(cell))
    }

    @ViewBuilder
    private func mark(_ cell: WeekDayCell) -> some View {
        switch state(cell) {
        case .done:
            Image(systemName: "checkmark")
                .iconMD(weight: .semibold)
                .foregroundColor(V3Tokens.ink)
                .transition(.opacity)
        case .half:
            Image(systemName: "circle.lefthalf.filled")
                .iconSM()
                .foregroundColor(V3Tokens.ink)
        case .open:
            Text(verbatim: "\(cell.day.day)")
                .bodyMDSemibold()
                .foregroundColor(cell.isToday ? V3Tokens.ink : V3Tokens.faintText)
        case .future:
            Text(verbatim: "\(cell.day.day)")
                .bodyMD()
                .foregroundColor(V3Tokens.faintText)
        }
    }

    private func accessibilityLabel(_ cell: WeekDayCell) -> String {
        let date = cell.day.startDate(in: .current)?.formatted(.dateTime.weekday(.wide).day().month(.wide)) ?? cell.day.string
        let status: String
        switch cell.state {
        case .done:   status = NSLocalizedString("one2.week.done", comment: "Week strip: day complete")
        case .half:   status = NSLocalizedString("one2.week.half", comment: "Week strip: half complete")
        case .open:   status = NSLocalizedString("one2.week.open", comment: "Week strip: not complete")
        case .future: status = NSLocalizedString("one2.week.future", comment: "Week strip: upcoming day")
        }
        return cell.isToday ? "\(ONE2Tab.today.title), \(date), \(status)" : "\(date), \(status)"
    }
}
