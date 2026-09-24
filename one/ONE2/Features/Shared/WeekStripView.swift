//
//  WeekStripView.swift
//  ONE 2.0
//
//  Hafta şeridi (WeekStrip.md, 06 › Bugün 2): gün kısaltması + tarih.
//  done: tik · half: yarım disk · gap: sönük tarih (7 gün içindeyse
//  dokununca doldurma) · today: çerçeveli, kalın · future: sönük,
//  dokunulamaz. Kapanışta (`revealToday`) bugünün hücresi tike döner.
//

import SwiftUI

struct WeekStripView: View {
    let days: [WeekDayViewData]
    var revealToday = false
    /// Doldurulabilir boş güne dokunuş; `nil` ise hücreler dokunulamaz.
    var onBackfill: ((WeekDayViewData) -> Void)?

    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                cell(day)
                    .frame(maxWidth: .infinity)
            }
        }
        .task {
            guard revealToday, !revealed else { return }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(reduceMotion ? nil : ONEAnimation.easingSaved) { revealed = true }
        }
    }

    private func status(_ day: WeekDayViewData) -> WeekDayStatus {
        revealToday && day.isToday && !revealed ? .today : day.status
    }

    @ViewBuilder
    private func cell(_ day: WeekDayViewData) -> some View {
        if day.canBackfill, let onBackfill {
            Button { onBackfill(day) } label: {
                column(day).contentShape(Rectangle())
            }
            .buttonStyle(.onePressable)
            .accessibilityHint(NSLocalizedString("one2.week.backfillHint", comment: "Week strip: tap to fill this day"))
        } else {
            column(day)
        }
    }

    private func column(_ day: WeekDayViewData) -> some View {
        VStack(spacing: V3Tokens.spacingXS) {
            Text(day.weekdayLabel)
                .v3MicroLabel(0.4)
                .foregroundColor(V3Tokens.mutedText)
            mark(day)
                .frame(width: V3Tokens.minTouchTarget, height: V3Tokens.minTouchTarget)
                .overlay {
                    if day.isToday {
                        RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                            .strokeBorder(V3Tokens.lineStrong, lineWidth: 1)
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(day))
    }

    @ViewBuilder
    private func mark(_ day: WeekDayViewData) -> some View {
        switch status(day) {
        case .done:
            Image(systemName: "checkmark")
                .iconMD(weight: .semibold)
                .foregroundColor(V3Tokens.ink)
                .transition(.opacity)
        case .half:
            Image(systemName: "circle.lefthalf.filled")
                .iconSM()
                .foregroundColor(V3Tokens.ink)
        case .today:
            Text(verbatim: "\(day.dayNumber)")
                .bodyMDSemibold()
                .foregroundColor(V3Tokens.ink)
        case .gap, .future:
            Text(verbatim: "\(day.dayNumber)")
                .bodyMD()
                .foregroundColor(V3Tokens.faintText)
        }
    }

    private func accessibilityLabel(_ day: WeekDayViewData) -> String {
        let status: String
        switch day.status {
        case .done:   status = NSLocalizedString("one2.week.done", comment: "Week strip: day complete")
        case .half:   status = NSLocalizedString("one2.week.half", comment: "Week strip: half complete")
        case .gap, .today: status = NSLocalizedString("one2.week.open", comment: "Week strip: not complete")
        case .future: status = NSLocalizedString("one2.week.future", comment: "Week strip: upcoming day")
        }
        return day.isToday ? "\(ONE2Tab.today.title), \(day.longLabel), \(status)" : "\(day.longLabel), \(status)"
    }
}
