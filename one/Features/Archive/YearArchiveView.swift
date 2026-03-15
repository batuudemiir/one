//
//  YearArchiveView.swift
//  One - Günlük Mood
//
//  UX redesign:
//  • Her ay için mini takvim grid (doğru gün sayısı ve haftaiçi offset)
//  • Ay adı + doluluk istatistiği
//  • Tıklayınca MonthArchiveView'e geçiş
//

import SwiftUI

struct YearArchiveView: View {
    let yearData: [MonthSummary]
    let onMonthTap: (Int) -> Void
    let onAyTap: () -> Void

    // Dikey 2 sütun grid
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 52)
                    .padding(.horizontal, 22)

                // Yıl özet bar
                yearSummaryBar
                    .padding(.horizontal, 22)
                    .padding(.top, 16)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(yearData, id: \.month) { summary in
                        MonthMiniCard(summary: summary) {
                            onMonthTap(summary.month)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)

                Spacer().frame(height: 100)
            }
        }
        .background(ONETokens.oneCream.ignoresSafeArea())
    }

    // MARK: — Başlık
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(yearData.first?.year ?? Calendar.current.component(.year, from: Date())))
                    .displayLG()
                    .foregroundColor(ONETokens.oneInk)
                Text("Müzik yılın")
                    .bodyXS()
                    .foregroundColor(ONETokens.oneAsh)
            }

            Spacer()

            // Görünüm toggle
            HStack(spacing: 6) {
                toggleBtn("AY",  active: false) { onAyTap() }
                toggleBtn("YIL", active: true,  action: nil)
            }
        }
    }

    private func toggleBtn(_ label: String, active: Bool, action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Text(label)
                .monoBase(tracking: 2)
                .foregroundColor(active ? ONETokens.oneCream : ONETokens.oneAsh)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(active ? ONETokens.oneInk : Color.clear)
                        .overlay(Capsule().stroke(ONETokens.oneStone, lineWidth: active ? 0 : 1))
                )
        }
        .disabled(active)
    }

    // MARK: — Yıllık istatistik bar
    private var yearSummaryBar: some View {
        let totalFilled  = yearData.reduce(0) { $0 + $1.filledDays }
        let totalDays    = yearData.reduce(0) { $0 + $1.totalDays }
        let activMonths  = yearData.filter { $0.filledDays > 0 }.count

        return HStack(spacing: 0) {
            statCell(val: "\(totalFilled)", lbl: "Toplam seçim")
            Divider().frame(height: 28)
            statCell(val: "\(activMonths)", lbl: "Aktif ay")
            Divider().frame(height: 28)
            let pct = totalDays > 0 ? Int(Double(totalFilled) / Double(totalDays) * 100) : 0
            statCell(val: "%\(pct)", lbl: "Yıl doluluk")
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))
    }

    private func statCell(val: String, lbl: String) -> some View {
        VStack(spacing: 2) {
            Text(val)
                .displaySM()
                .foregroundColor(ONETokens.oneInk)
            Text(lbl)
                .monoLabel()
                .foregroundColor(ONETokens.oneAsh)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: — Mini Ay Kartı
struct MonthMiniCard: View {
    let summary: MonthSummary
    let onTap: () -> Void

    private let miniColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private var isCurrentMonth: Bool {
        let cal = Calendar.current; let now = Date()
        return summary.year  == cal.component(.year,  from: now) &&
               summary.month == cal.component(.month, from: now)
    }

    var body: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 8) {

                // Ay adı + doluluk
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.monthNameShort)
                        .bodySM()
                        .fontWeight(.semibold)
                        .foregroundColor(isCurrentMonth ? ONETokens.oneInk : ONETokens.oneCharcoal)

                    Spacer()

                    Text("\(summary.filledDays)/\(summary.totalDays)")
                        .monoSM()
                        .foregroundColor(ONETokens.oneAsh)
                }

                // Gün adları mini başlık
                HStack(spacing: 0) {
                    ForEach(["P","S","Ç","P","C","C","P"], id: \.self) { d in
                        Text(d)
                            .monoMicro()
                            .foregroundColor(ONETokens.oneStone)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Mini takvim grid — doğru gün offsetiyle
                let cells = summary.calendarCells
                LazyVGrid(columns: miniColumns, spacing: 2) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                        miniCell(for: date)
                    }
                }

                // Doluluk progress bar
                GeometryReader { geo in
                    let pct = summary.totalDays > 0
                        ? CGFloat(summary.filledDays) / CGFloat(summary.totalDays)
                        : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(ONETokens.oneSilver).frame(height: 3)
                        Capsule()
                            .fill(isCurrentMonth ? ONETokens.oneInk : ONETokens.oneMist)
                            .frame(width: geo.size.width * pct, height: 3)
                    }
                }
                .frame(height: 3)
            }
            .padding(12)
            .background(Color.white.opacity(isCurrentMonth ? 0.92 : 0.72))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isCurrentMonth ? ONETokens.oneInk.opacity(0.15) : ONETokens.oneSilver,
                        lineWidth: isCurrentMonth ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func miniCell(for date: Date?) -> some View {
        if let date {
            if let entry = summary.entries[date] {
                // Dolu gün — mood rengi
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: entry.moodColorHex))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        // Bugün — beyaz kenarlık
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.white, lineWidth: Calendar.current.isDateInToday(date) ? 1.5 : 0)
                    )
            } else {
                // Boş gün — soluk placeholder
                RoundedRectangle(cornerRadius: 2)
                    .fill(ONETokens.oneIvory.opacity(0.6))
                    .aspectRatio(1, contentMode: .fit)
            }
        } else {
            // Offset placeholder
            Color.clear
                .aspectRatio(1, contentMode: .fit)
        }
    }
}
