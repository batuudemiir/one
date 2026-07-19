//
//  ArchiveMosaicView.swift
//  one
//
//  Prototipteki arşiv: ay/yıl geçişi yok — tek akışta aylar, her ay bir mozaik.
//

import SwiftUI

/// Arşiv, prototipte bir gezinme değil bir **doku**: aşağı kaydırdıkça
/// aylar birbirini izler, renkler biriktikçe ekran güzelleşir. Ay/yıl
/// geçişli iki ayrı görünüm bu birikimi parçalara bölüyordu.
struct ArchiveMosaicView: View {
    let months: [MonthSummary]
    let lastYearToday: DailyEntry?

    /// Prototip `.mosaic`: 7 sütun, 4pt aralık, kare hücreler, 5pt köşe.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// En yeni ay üstte; kaydı olmayan aylar hiç çizilmez — boş ızgaralar
    /// arşivi dolu değil, terk edilmiş gösteriyordu.
    private var visibleMonths: [MonthSummary] {
        months
            .filter { $0.filledDays > 0 }
            .sorted { ($0.year, $0.month) > ($1.year, $1.month) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(NSLocalizedString("archive.title", comment: ""))
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)

                Text(NSLocalizedString("archive.subtitle", comment: ""))
                    .bodySM()
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.top, 7)

                if visibleMonths.isEmpty {
                    emptyState
                } else {
                    ForEach(visibleMonths, id: \.monthKey) { month in
                        Text(monthLabel(month))
                            .monoLabel(tracking: 1.3)
                            .foregroundColor(ONETokens.oneStone)
                            .padding(.top, ONETokens.spacingXL)

                        mosaic(for: month)
                            .padding(.top, ONETokens.spacingMD)
                    }
                }

                if let entry = lastYearToday {
                    Rectangle()
                        .fill(ONETokens.oneInk.opacity(0.09))
                        .frame(height: 1)
                        .padding(.vertical, ONETokens.spacingXL)

                    lastYearCard(entry)
                }
            }
            .padding(.horizontal, ONETokens.spacingXL)
            .padding(.top, ONETokens.spacingXL3)
            .padding(.bottom, 116)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Mosaic

    private func mosaic(for month: MonthSummary) -> some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(1...month.totalDays, id: \.self) { day in
                cell(for: day, in: month)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    @ViewBuilder
    private func cell(for day: Int, in month: MonthSummary) -> some View {
        let color = entryColor(day: day, month: month)

        RoundedRectangle(cornerRadius: 5, style: .continuous)
            // Boş gün silinmez, soluk kalır: ritmin nerede koptuğu da veri.
            .fill(color ?? ONETokens.oneInk.opacity(0.05))
            .accessibilityLabel(accessibilityLabel(day: day, month: month))
    }

    private func entryColor(day: Int, month: MonthSummary) -> Color? {
        guard let date = Calendar.current.date(
            from: DateComponents(year: month.year, month: month.month, day: day)
        ) else { return nil }
        return month.primaryEntry(for: date)?.moodColor
    }

    private func accessibilityLabel(day: Int, month: MonthSummary) -> String {
        guard let date = Calendar.current.date(
            from: DateComponents(year: month.year, month: month.month, day: day)
        ), let entry = month.primaryEntry(for: date) else {
            return "\(day), boş"
        }
        return "\(day), \(entry.moodLabel)"
    }

    // MARK: Last year

    private func lastYearCard(_ entry: DailyEntry) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(NSLocalizedString("archive.lastYearLabel", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(ONETokens.oneStone)

            (
                Text(lastYearDateText(entry.date) + "'te ")
                    .foregroundColor(ONETokens.oneInk)
                + Text(entry.moodLabel)
                    .foregroundColor(Color(hex: entry.moodColorHex))
                    .fontWeight(.semibold)
                + Text(" hissediyordun.")
                    .foregroundColor(ONETokens.oneInk)
            )
            .bodySM()

            Text("\(entry.songName) — \(entry.artistName)")
                .bodyXS()
                .foregroundColor(ONETokens.oneAsh)
        }
        .padding(ONETokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                .fill(Color.white.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                .stroke(ONETokens.oneInk.opacity(0.09), lineWidth: 1)
        )
    }

    // MARK: Empty

    private var emptyState: some View {
        Text(NSLocalizedString("archive.empty", comment: ""))
            .bodySM()
            .foregroundColor(ONETokens.oneAsh)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, ONETokens.spacingXL3)
    }

    // MARK: Formatting

    private func monthLabel(_ month: MonthSummary) -> String {
        var components = DateComponents()
        components.year = month.year
        components.month = month.month
        guard let date = Calendar.current.date(from: components) else { return "" }

        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date).lowercased()
    }

    private func lastYearDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter.string(from: date)
    }
}

private extension MonthSummary {
    /// `ForEach` için sabit kimlik — yıl+ay tek bir ayı benzersiz belirler.
    var monthKey: Int { year * 100 + month }
}
