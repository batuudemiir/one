//
//  BackfillSheet.swift
//  ONE 2.0
//
//  Boş kalmış geçmiş güne dokununca (son 7 gün; 07 §5.1): "Dün boş kaldı.
//  İstersen şimdi doldurabilirsin." + `Check-in yap` / `Yaz`. Suçlama ya da
//  yalvarma yok; sayfa sürükleyerek kapanır. Daha eski günde açılmaz.
//

import SwiftUI

struct BackfillSheet: View {
    let day: WeekDayState
    let today: DayKey
    let onCheckIn: () -> Void
    let onWrite: () -> Void

    /// Sayfa içeriği kadar açılır (Dynamic Type ile büyür).
    @State private var height: CGFloat = 0

    private var title: String {
        if day.day.days(to: today) == 1 {
            return one2String("one2.today.backfill.yesterday")
        }
        return String(format: one2String("one2.today.backfill.day"), one2String("one2.weekday.long.\(day.weekday)"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s5) {
            VStack(alignment: .leading, spacing: ONE2Space.s2) {
                Text(title)
                    .one2Type(.titleSm)
                    .foregroundStyle(ONE2Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(one2String("one2.today.backfill.body"))
                    .one2Type(.body)
                    .foregroundStyle(ONE2Color.inkMuted)
            }
            VStack(spacing: ONE2Space.s2) {
                Button(action: onCheckIn) {
                    Text(one2String("one2.today.backfill.checkIn")).contentShape(Rectangle())
                }
                .buttonStyle(.one2(.primary, fullWidth: true))
                Button(action: onWrite) {
                    Text(one2String("one2.today.backfill.write")).contentShape(Rectangle())
                }
                .buttonStyle(.one2(.secondary, fullWidth: true))
            }
        }
        .padding(.horizontal, ONE2Space.gutter)
        .padding(.top, ONE2Space.s8)
        .padding(.bottom, ONE2Space.s4)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents(height > 0 ? [.height(height)] : [.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(ONE2Radius.xl)
        .presentationBackground(ONE2Color.surface)
    }
}

#if DEBUG
private struct BackfillSheetHost: View {
    var body: some View {
        let today = FixtureClock.today
        let week = TodayFixture.weekFew
        let yesterday = week.days.first { $0.day == today.adding(days: -1) }!
        ONE2Color.ground.ignoresSafeArea()
            .sheet(isPresented: .constant(true)) {
                BackfillSheet(day: yesterday, today: today, onCheckIn: {}, onWrite: {})
            }
    }
}

#Preview("Gece") { BackfillSheetHost().preferredColorScheme(.dark) }
#Preview("Gün") { BackfillSheetHost().preferredColorScheme(.light) }
#Preview("AX3") { BackfillSheetHost().preferredColorScheme(.dark).dynamicTypeSize(.accessibility3) }
#endif
