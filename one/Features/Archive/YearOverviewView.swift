//
//  YearOverviewView.swift
//  one
//
//  Prototip 17 — "bir yıl". Arşivin üstünden bakış.
//

import SwiftUI

/// Yıl görünümü.
///
/// Prototipin kilit cümlesi alt başlıkta: **"198 gün işaretlendi.
/// 167 gün boş — sorun değil."** Boş günleri bir eksiklik değil, doğal
/// bir oran olarak sunuyor. Bu ürünün streak'e değil ritme bakmasının
/// yıl ölçeğindeki karşılığı.
struct YearOverviewView: View {
    let months: [MonthSummary]
    let onBack: () -> Void
    var onMonthTap: ((MonthSummary) -> Void)? = nil
    /// Bir güne dokunulunca o günün detayı. Hücreler eskiden salt
    /// gösterimdi — yıl görünümünden güne inilemiyordu.
    var onDayTap: ((DailyEntry) -> Void)? = nil
    var onPoster: (() -> Void)? = nil

    private var year: Int {
        months.first?.year ?? Calendar.current.component(.year, from: Date())
    }

    private var filledDays: Int { months.reduce(0) { $0 + $1.filledDays } }

    private var totalDays: Int {
        // Geçmiş ve içinde bulunulan aylar — gelecek aylar "boş" sayılmaz.
        let now = Date()
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: now)
        let currentMonth = cal.component(.month, from: now)
        return months
            .filter { year < currentYear || $0.month <= currentMonth }
            .reduce(0) { $0 + $1.totalDays }
    }

    private var emptyDays: Int { max(totalDays - filledDays, 0) }

    private var distinctColors: Int {
        Set(months.flatMap { $0.entries.values.flatMap { $0.map(\.moodColorHex) } }).count
    }

    private var fullWeeks: Int {
        let all = months.flatMap { $0.entries.keys }
        let cal = Calendar.current
        let weeks = Dictionary(grouping: all) {
            cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: $0)
        }
        return weeks.values.filter { $0.count == 7 }.count
    }

    var body: some View {
        SubScreen(
            title: "\(year)",
            actionTitle: onPoster != nil ? NSLocalizedString("year.poster", comment: "") : nil,
            onBack: onBack,
            onAction: onPoster
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(NSLocalizedString("year.title", comment: ""))
                    .displayLG()
                    .foregroundColor(V3Tokens.ink)

                Text(String(
                    format: NSLocalizedString("year.subtitle", comment: ""),
                    filledDays, emptyDays
                ))
                .bodySM()
                .foregroundColor(V3Tokens.mutedText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)

                StatRow(items: [
                    ("\(filledDays)", NSLocalizedString("profile.stat.entries", comment: "")),
                    ("\(distinctColors)", NSLocalizedString("year.colours", comment: "")),
                    ("\(fullWeeks)", NSLocalizedString("profile.stat.fullWeeks", comment: ""))
                ])
                .padding(.vertical, ONETokens.spacingLG)

                monthGrid

                Rectangle()
                    .fill(V3Tokens.ink.opacity(0.09))
                    .frame(height: 1)
                    .padding(.vertical, ONETokens.spacingXL)

                if let shape = yearShape {
                    InsightCard(label: NSLocalizedString("year.shapeLabel", comment: "")) {
                        Text(shape)
                            .bodySM()
                            .foregroundColor(V3Tokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Ay ızgarası

    /// Prototipteki `.yr`: 3 sütun, her ay kendi mini 6-sütunlu mozaiği.
    private var monthGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 3),
            spacing: 11
        ) {
            ForEach(months.sorted { $0.month < $1.month }, id: \.month) { month in
                VStack(alignment: .leading, spacing: 6) {
                        Text(monthName(month.month))
                            .font(V3Typography.sans(10))
                            .foregroundColor(V3Tokens.mutedText)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 6),
                            spacing: 2
                        ) {
                            ForEach(1...month.totalDays, id: \.self) { day in
                                dayCell(day: day, in: month)
                            }
                        }
                    }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .oneCardBackground(radius: 12, opacity: 0.6)
                .accessibilityElement(children: .contain)
            }
        }
    }

    /// Dolu gün dokunulabilir, boş gün değil — boş bir güne dokunmak
    /// açılacak bir şey olmadığı için sessiz kalırdı.
    @ViewBuilder
    private func dayCell(day: Int, in month: MonthSummary) -> some View {
        let entry = entryFor(day: day, in: month)
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(entry?.moodColor ?? V3Tokens.ink.opacity(0.06))
            .aspectRatio(1, contentMode: .fit)

        if let entry, let onDayTap {
            Button { onDayTap(entry) } label: { shape }
                .buttonStyle(.plain)
                .accessibilityLabel("\(day) \(monthName(month.month)), \(entry.moodLabel)")
        } else {
            shape.accessibilityHidden(true)
        }
    }

    private func entryFor(day: Int, in month: MonthSummary) -> DailyEntry? {
        guard let date = Calendar.current.date(
            from: DateComponents(year: month.year, month: month.month, day: day)
        ) else { return nil }
        return month.primaryEntry(for: date)
    }


    private func monthName(_ month: Int) -> String {
        var comps = DateComponents(); comps.year = year; comps.month = month
        guard let date = Calendar.current.date(from: comps) else { return "" }
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMMM")
        return f.string(from: date).lowercased()
    }

    // MARK: Yılın şekli

    /// Prototipte bu cümle elle yazılmış ("Şubat ve kasım en koyu aylar…").
    /// Uydurmak yerine gerçek veriden türetiyoruz: en dolu ay ve baskın mood.
    /// Veri yetmiyorsa kart hiç çizilmiyor — boş bir içgörü, içgörü değil.
    private var yearShape: String? {
        guard filledDays >= 12 else { return nil }

        let busiest = months.max { $0.filledDays < $1.filledDays }
        let labels = months.flatMap { $0.entries.values.flatMap { $0.map(\.moodLabel) } }
        let dominant = Dictionary(grouping: labels, by: { $0 })
            .max { $0.value.count < $1.value.count }?.key

        guard let busiest, busiest.filledDays > 0, let dominant else { return nil }

        return String(
            format: NSLocalizedString("year.shapeFormat", comment: ""),
            monthName(busiest.month), dominant
        )
    }
}
