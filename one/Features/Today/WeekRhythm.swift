//
//  WeekRhythm.swift
//  one
//
//  Faz 3 — Habit loop: haftalık 7 nokta sırası.
//
//  Felsefe: hedef "her gün" değil, "haftada 4 gün = tamamlanmış hafta".
//  Kaçırılan gün ceza değil, doldurulabilir bir boşluk. Streak'ten farkı:
//  streak kesintisizliği ölçer, ritim ise haftalık toplamı — kırılmaz,
//  sadece dolar. Bu yüzden dil suçlayıcı değil, davetkâr.
//

import SwiftUI

// MARK: - Model

enum WeekRhythm {
    /// Haftanın "tamamlanmış" sayılması için gereken dolu gün sayısı.
    static let completionTarget: Int = 4

    /// Bugün hariç geriye kaç gün doldurulabilir (brief: 24–72 saat).
    static let backfillWindowDays: Int = 2

    struct Day: Identifiable, Equatable {
        let date: Date
        /// Doluysa o günün mood rengi, boşsa nil.
        let moodColorHex: String?
        let isToday: Bool
        let isFuture: Bool
        /// Geçmiş + boş + telafi penceresi içinde → tek dokunuşla doldurulabilir.
        let isBackfillable: Bool

        var id: Date { date }
        var isFilled: Bool { moodColorHex != nil }
    }

    /// İçinde bulunulan haftanın 7 gününü, kullanıcının takvim diline göre
    /// (firstWeekday) sırayla üretir.
    ///
    /// - Parameters:
    ///   - filled: gün başlangıcı → mood rengi hex eşlemesi.
    ///   - today: referans gün (gün başlangıcı olması gerekmez).
    static func days(
        filled: [Date: String],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [Day] {
        let todayStart = calendar.startOfDay(for: today)
        guard let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: todayStart)
        ) else { return [] }

        let backfillFloor = calendar.date(
            byAdding: .day, value: -backfillWindowDays, to: todayStart
        ) ?? todayStart

        return (0..<7).compactMap { offset -> Day? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let hex = filled[dayStart]
            let isToday = dayStart == todayStart
            let isFuture = dayStart > todayStart
            let isBackfillable = hex == nil
                && !isToday
                && !isFuture
                && dayStart >= backfillFloor

            return Day(
                date: dayStart,
                moodColorHex: hex,
                isToday: isToday,
                isFuture: isFuture,
                isBackfillable: isBackfillable
            )
        }
    }

    static func filledCount(_ days: [Day]) -> Int {
        days.filter(\.isFilled).count
    }

    static func isComplete(_ days: [Day]) -> Bool {
        filledCount(days) >= completionTarget
    }

    /// Verilen tarih telafi penceresi içinde mi? (VM tarafındaki guard ile
    /// aynı kuralı paylaşır — tek kaynak.)
    static func isBackfillable(
        _ date: Date,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: today)
        guard dayStart < todayStart else { return false }
        guard let floor = calendar.date(byAdding: .day, value: -backfillWindowDays, to: todayStart) else { return false }
        return dayStart >= floor
    }
}

/// `.sheet(item:)` Identifiable ister — çıplak `Date` bunu sağlamıyor.
struct BackfillTarget: Identifiable, Equatable {
    let date: Date
    var id: Date { date }
}

// MARK: - View

/// Haftanın 7 günü — dolu günler mood rengi, bugün halka, telafi edilebilir
/// günler kesikli çember (dokunulabilir), kalanlar soluk.
struct WeekRhythmView: View {
    let days: [WeekRhythm.Day]
    /// Telafi edilebilir bir güne dokunulduğunda çağrılır.
    var onBackfill: (Date) -> Void = { _ in }

    private var filledCount: Int { WeekRhythm.filledCount(days) }
    private var isComplete: Bool { WeekRhythm.isComplete(days) }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(days) { day in
                    dayColumn(day)
                        .frame(maxWidth: .infinity)
                }
            }

            summaryLabel
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Day column

    @ViewBuilder
    private func dayColumn(_ day: WeekRhythm.Day) -> some View {
        let content = VStack(spacing: 6) {
            dot(day)
                .frame(width: 22, height: 22)
            Text(weekdayInitial(day.date))
                .monoLabel(tracking: 0.4)
                .foregroundColor(day.isToday ? ONETokens.oneInk : ONETokens.oneAsh)
                .opacity(day.isFuture ? 0.4 : 1)
        }

        if day.isBackfillable {
            Button { onBackfill(day.date) } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(day))
                .accessibilityHint("Bu günü şimdi doldur")
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel(day))
        }
    }

    @ViewBuilder
    private func dot(_ day: WeekRhythm.Day) -> some View {
        if let hex = day.moodColorHex {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 12, height: 12)
                .overlay {
                    if day.isToday {
                        Circle()
                            .stroke(ONETokens.oneInk.opacity(0.35), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                    }
                }
        } else if day.isToday {
            // Bugün henüz boş — davet: içi boş ama net bir halka.
            Circle()
                .stroke(ONETokens.oneInk, lineWidth: 1.5)
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .stroke(ONETokens.oneInk.opacity(0.18), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
        } else if day.isBackfillable {
            // Telafi edilebilir — kesikli çember dokunulabilirliği işaret eder.
            Circle()
                .strokeBorder(
                    ONETokens.oneAsh,
                    style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2.5])
                )
                .frame(width: 12, height: 12)
        } else {
            Circle()
                .fill(ONETokens.oneSilver)
                .frame(width: 6, height: 6)
                .opacity(day.isFuture ? 0.5 : 1)
        }
    }

    // MARK: Summary

    private var summaryLabel: some View {
        HStack(spacing: 6) {
            if isComplete {
                Circle()
                    .fill(ONETokens.oneBrand)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
            Text(summaryText)
                .bodyXS()
                .foregroundColor(isComplete ? ONETokens.oneInk : ONETokens.oneAsh)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summaryText)
    }

    private var summaryText: String {
        isComplete
            ? "Bu hafta tamamlandı — \(filledCount) gün"
            : "Bu hafta \(filledCount)/\(WeekRhythm.completionTarget) gün"
    }

    // MARK: Helpers

    private func weekdayInitial(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date).uppercased()
    }

    private func accessibilityLabel(_ day: WeekRhythm.Day) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        let name = formatter.string(from: day.date)

        if day.isFilled { return "\(name), dolu" }
        if day.isToday { return "\(name), bugün, henüz boş" }
        if day.isBackfillable { return "\(name), boş, doldurulabilir" }
        return "\(name), boş"
    }
}

#Preview {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let filled: [Date: String] = [
        cal.date(byAdding: .day, value: -4, to: today)!: "#E8734A",
        cal.date(byAdding: .day, value: -3, to: today)!: "#5B8DEF",
        cal.date(byAdding: .day, value: -1, to: today)!: "#9B7EDE"
    ]
    return WeekRhythmView(days: WeekRhythm.days(filled: filled, today: today))
        .padding(24)
        .background(ONETokens.oneCream)
}
