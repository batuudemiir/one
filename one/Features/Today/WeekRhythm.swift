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

    /// Prototip düzeni: yatay kart — noktalar solda, hedef sağda.
    /// Gün harfleri (P S Ç…) bilinçli olarak yok; hangi günün hangisi olduğu
    /// noktanın konumundan zaten okunuyor ve harfler satırı kalabalıklaştırıp
    /// ritmi bir takvime çeviriyordu. Gün adları VoiceOver'da korunuyor.
    var body: some View {
        HStack(spacing: 9) {
            HStack(spacing: 6) {
                ForEach(days) { day in
                    dayDot(day)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            goalLabel
        }
        .padding(.horizontal, ONETokens.spacingLG)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                .fill(Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                .stroke(ONETokens.oneInk.opacity(0.09), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    // MARK: Day dot

    @ViewBuilder
    private func dayDot(_ day: WeekRhythm.Day) -> some View {
        let content = dot(day).frame(width: 19, height: 19)

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

    /// Prototipteki `.rd`: 19pt çember. Dolu gün rengi tamamen doldurur,
    /// bugün çift halkayla ayrışır, telafi edilebilir gün kesikli.
    @ViewBuilder
    private func dot(_ day: WeekRhythm.Day) -> some View {
        if let hex = day.moodColorHex {
            Circle()
                .fill(Color(hex: hex))
                .overlay { if day.isToday { todayRing } }
        } else if day.isToday {
            // Bugün henüz boş — davet: içi boş ama net bir halka.
            Circle()
                .strokeBorder(ONETokens.oneInk.opacity(0.14), lineWidth: 1.5)
                .overlay { todayRing }
        } else if day.isBackfillable {
            // Kesikli çember dokunulabilirliği işaret eder.
            Circle()
                .strokeBorder(
                    ONETokens.oneAsh,
                    style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2.5])
                )
        } else {
            Circle()
                .strokeBorder(ONETokens.oneInk.opacity(0.14), lineWidth: 1.5)
                .opacity(day.isFuture ? 0.5 : 1)
        }
    }

    /// Prototipteki `box-shadow:0 0 0 2px cream, 0 0 0 3.5px ink` — noktanın
    /// dışında krem bir boşluk, onun dışında ince mürekkep halka.
    private var todayRing: some View {
        Circle()
            .stroke(ONETokens.oneCream, lineWidth: 2)
            .overlay(
                Circle().stroke(ONETokens.oneInk, lineWidth: 1.5)
                    .padding(-1.75)
            )
            .padding(-1)
    }

    // MARK: Goal

    /// Sağ kolon: "bu hafta" / "3/4 gün" — iki satır, sağa yaslı mono.
    private var goalLabel: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("bu hafta")
                .monoLabel(tracking: 0.2)
                .foregroundColor(ONETokens.oneAsh)
            Text(goalText)
                .monoLabel(tracking: 0.2)
                .foregroundColor(ONETokens.oneInk)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summaryText)
    }

    private var goalText: String {
        isComplete ? "\(filledCount) gün ✓" : "\(filledCount)/\(WeekRhythm.completionTarget) gün"
    }

    private var summaryText: String {
        isComplete
            ? "Bu hafta tamamlandı — \(filledCount) gün"
            : "Bu hafta \(filledCount)/\(WeekRhythm.completionTarget) gün"
    }

    // MARK: Helpers


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
