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
    /// Bir güne dokunulduğunda o günün detayı açılır.
    var onDayTap: ((DailyEntry) -> Void)? = nil
    /// Sağ üstteki yıl görünümü.
    var onYearTap: (() -> Void)? = nil

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
                HStack(alignment: .firstTextBaseline) {
                    Text(NSLocalizedString("archive.title", comment: ""))
                        .displayLG()
                        .foregroundColor(V3Tokens.ink)

                    Spacer()

                    if let onYearTap {
                        Button(action: onYearTap) {
                            Text(NSLocalizedString("archive.yearView", comment: ""))
                                .font(V3Typography.sans(13, weight: .semibold))
                                .foregroundColor(ONEBrand.kor)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(NSLocalizedString("archive.subtitle", comment: ""))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.top, 7)

                if visibleMonths.isEmpty {
                    emptyState
                } else {
                    ForEach(visibleMonths, id: \.monthKey) { month in
                        Text(monthLabel(month))
                            .monoLabel(tracking: 1.3)
                            .foregroundColor(V3Tokens.faintText)
                            .padding(.top, ONETokens.spacingXL)

                        mosaic(for: month)
                            .padding(.top, ONETokens.spacingMD)
                    }
                }

                if let entry = lastYearToday {
                    Rectangle()
                        .fill(V3Tokens.ink.opacity(0.09))
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
        let hexes = entryHexes(day: day, month: month)

        // v3: 1 an = düz renk, 2+ an = 135° diyagonal dilimler. `DayFill`
        // boş gün için kesikli çerçeve çiziyor — burada ayrı EmptyDayCell'e
        // gerek yok, DayFill zaten empty state'i biliyor.
        let fill = DayFill(hexes: hexes, cornerRadius: 9)

        if !hexes.isEmpty, let entry = primaryEntry(day: day, month: month), let onDayTap {
            Button { onDayTap(entry) } label: { fill }
                .buttonStyle(.plain)
                // Apple 44pt hit-target: Dynamic Type Large'ta hücre inebilir.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(accessibilityLabel(day: day, month: month))
                .accessibilityHint("Detayları aç")
                .accessibilityAddTraits(.isButton)
        } else {
            // Boş gün: DayFill'in dashed görseli + BounceOnTap ile hafif yay
            // + haptic. VoiceOver de focus edip "boş" label okuyor.
            fill
                .modifier(EmptyDayBounce())
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityElement()
                .accessibilityLabel(accessibilityLabel(day: day, month: month))
        }
    }

    /// Boş hücrede tap → mikro yay + haptic. Delight sinyali "burada veri yok"
    /// yerine "burayı doldurabilirsin" mesajı taşıyor.
    private struct EmptyDayBounce: ViewModifier {
        @State private var bounced = false
        func body(content: Content) -> some View {
            content
                .scaleEffect(bounced ? 0.92 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.55), value: bounced)
                .onTapGesture {
                    ONEHaptics.tabSwitch()
                    bounced = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(180))
                        bounced = false
                    }
                }
        }
    }

    private func entryHexes(day: Int, month: MonthSummary) -> [String] {
        guard let date = Calendar.current.date(
            from: DateComponents(year: month.year, month: month.month, day: day)
        ) else { return [] }
        return month.allEntries(for: date).map(\.moodColorHex)
    }

    private func primaryEntry(day: Int, month: MonthSummary) -> DailyEntry? {
        guard let date = Calendar.current.date(
            from: DateComponents(year: month.year, month: month.month, day: day)
        ) else { return nil }
        return month.primaryEntry(for: date)
    }

    /// Boş gün hücresi — dokunduğunda hafif haptic + minik yay ile
    /// "burada veri yok" sinyalini görsel/dokunsal olarak verir.
    private struct EmptyDayCell: View {
        @State private var bounced = false

        var body: some View {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(V3Tokens.ink.opacity(0.05))
                .scaleEffect(bounced ? 0.92 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.55), value: bounced)
                .contentShape(Rectangle())
                .onTapGesture {
                    ONEHaptics.tabSwitch()
                    bounced = true
                    // asyncAfter yerine structured Task: view kaybolursa
                    // Swift concurrency iptali sistem tarafından yönetilebilir,
                    // "view gone before deadline" fragility ortadan kalkar.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(180))
                        bounced = false
                    }
                }
        }
    }

    private func entryFor(day: Int, month: MonthSummary) -> DailyEntry? {
        guard let date = Calendar.current.date(
            from: DateComponents(year: month.year, month: month.month, day: day)
        ) else { return nil }
        return month.primaryEntry(for: date)
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
                .foregroundColor(V3Tokens.faintText)

            (
                Text(lastYearDateText(entry.date) + "'te ")
                    .foregroundColor(V3Tokens.ink)
                + Text(entry.moodLabel)
                    .foregroundColor(Color(hex: entry.moodColorHex))
                    .fontWeight(.semibold)
                + Text(" hissediyordun.")
                    .foregroundColor(V3Tokens.ink)
            )
            .bodySM()

            Text("\(entry.songName) — \(entry.artistName)")
                .bodyXS()
                .foregroundColor(V3Tokens.mutedText)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(ONETokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                .fill(Color.white.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                .stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1)
        )
    }

    // MARK: Empty

    private var emptyState: some View {
        Text(NSLocalizedString("archive.empty", comment: ""))
            .bodySM()
            .foregroundColor(V3Tokens.mutedText)
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
