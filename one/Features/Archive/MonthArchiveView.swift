//
//  MonthArchiveView.swift
//  One - Günlük Mood
//
//  UX redesign:
//  • ← / → ay navigasyonu (ArchiveStore.navigateMonth)
//  • Doğru Pazartesi-başlangıçlı takvim grid (MonthSummary.calendarCells ile)
//  • Her ayın gerçek gün sayısı otomatik hesaplanıyor (MonthSummary.totalDays)
//  • Daha büyük hücreler, net hiyerarşi, gün-adı başlıkları
//

import SwiftUI

struct MonthArchiveView: View {
    let summary: MonthSummary
    let onDayTap: (Date) -> Void
    let onYearTap: () -> Void

    @EnvironmentObject private var archiveStore: ArchiveStore
    @State private var previewEntries: [DailyEntry] = []
    @State private var previewIndex: Int = 0
    @State private var showPreview  = false
    @State private var appeared     = false
    @State private var cardDragOffset: CGFloat = 0
    @State private var isDraggingCard = false

    // Haftanın günleri — Pazartesi başlangıç
    private var weekDays: [String] {
        ["calendar.day.mon", "calendar.day.tue", "calendar.day.wed",
         "calendar.day.thu", "calendar.day.fri", "calendar.day.sat", "calendar.day.sun"]
            .map { NSLocalizedString($0, comment: "") }
    }

    var body: some View {
        ZStack {
            ONETokens.oneCream.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // MARK: — Başlık + Navigasyon
                    header
                        .padding(.top, 52)
                        .padding(.horizontal, 22)

                    // MARK: — İstatistik Özeti
                    statsRow
                        .padding(.horizontal, 22)
                        .padding(.top, 14)

                    // MARK: — Takvim
                    calendarCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // MARK: — Wave / Mood şeridi
                    moodStripSection
                        .padding(.horizontal, 22)
                        .padding(.top, 20)

                    Spacer().frame(height: 100)
                }
            }

            // MARK: — Önizleme overlay (single & multi-entry carousel)
            if showPreview, !previewEntries.isEmpty {
                // Full-screen dismiss background — hittable everywhere the card isn't
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(ONEAnimation.micro) { showPreview = false }
                    }

                // Manual card pager — only occupies card width so backdrop stays tappable
                VStack(spacing: 10) {
                    let cardW = UIScreen.main.bounds.width * 0.88

                    ZStack {
                        ForEach(Array(previewEntries.enumerated()), id: \.element.id) { idx, entry in
                            DayPreviewCard(entry: entry)
                                .offset(x: CGFloat(idx - previewIndex) * (cardW + 16) + cardDragOffset)
                                .animation(isDraggingCard ? nil : ONEAnimation.cardSpring, value: previewIndex)
                                .animation(isDraggingCard ? nil : ONEAnimation.cardSpring, value: cardDragOffset)
                        }
                    }
                    .frame(width: cardW, height: cardHeight)
                    .clipped()
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { val in
                                let h = val.translation.width
                                let v = val.translation.height
                                guard abs(h) > abs(v) else { return }
                                isDraggingCard = true
                                cardDragOffset = h
                            }
                            .onEnded { val in
                                isDraggingCard = false
                                let h = val.translation.width
                                let v = val.translation.height
                                guard abs(h) > abs(v) else {
                                    withAnimation(ONEAnimation.cardSpring) { cardDragOffset = 0 }
                                    return
                                }
                                if h < -44, previewIndex < previewEntries.count - 1 {
                                    ONEHaptics.tabSwitch()
                                    previewIndex += 1
                                } else if h > 44, previewIndex > 0 {
                                    ONEHaptics.tabSwitch()
                                    previewIndex -= 1
                                }
                                withAnimation(ONEAnimation.cardSpring) { cardDragOffset = 0 }
                            }
                    )

                    // Page indicator — only when multiple entries
                    if previewEntries.count > 1 {
                        HStack(spacing: 6) {
                            ForEach(0..<previewEntries.count, id: \.self) { idx in
                                Circle()
                                    .fill(idx == previewIndex
                                          ? Color(hex: previewEntries[idx].moodColorHex)
                                          : ONETokens.oneSilver)
                                    .frame(width: idx == previewIndex ? 8 : 6,
                                           height: idx == previewIndex ? 8 : 6)
                                    .animation(ONEAnimation.micro, value: previewIndex)
                                    .onTapGesture {
                                        withAnimation(ONEAnimation.cardSpring) { previewIndex = idx }
                                    }
                            }
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal:   .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .animation(ONEAnimation.cardSpring, value: showPreview)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.1)) { appeared = true }
        }
    }

    /// Estimate card height so TabView doesn't collapse
    private var cardHeight: CGFloat {
        let screen = UIScreen.main.bounds.height
        return min(screen * 0.75, 620)
    }

    // MARK: — Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Satır 1: ← Ay Adı →
            HStack(alignment: .center) {
                // ← Önceki ay
                Button {
                    ONEHaptics.tabSwitch()
                    withAnimation(ONEAnimation.cardSpring) {
                        archiveStore.navigateMonth(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ONETokens.oneAsh)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ONETokens.onePaper.opacity(0.8)))
                        .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                        .contentShape(Rectangle())
                }

                Spacer()

                // Ay + Yıl
                VStack(spacing: 2) {
                    Text(summary.monthName)
                        .displayLG()
                        .foregroundColor(ONETokens.oneInk)
                    Text(String(summary.year))
                        .monoSM(tracking: 2)
                        .foregroundColor(ONETokens.oneAsh)
                }

                Spacer()

                // → Sonraki ay
                Button {
                    ONEHaptics.tabSwitch()
                    withAnimation(ONEAnimation.cardSpring) {
                        archiveStore.navigateMonth(by: +1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(archiveStore.canGoForward ? ONETokens.oneAsh : ONETokens.oneStone)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(ONETokens.onePaper.opacity(archiveStore.canGoForward ? 0.8 : 0.4)))
                        .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .disabled(!archiveStore.canGoForward)
            }

            // Satır 2: Görünüm toggle (AY / YIL)
            HStack(spacing: 6) {
                viewToggleBtn(NSLocalizedString("archive.month", comment: ""),  active: true,  action: nil)
                viewToggleBtn(NSLocalizedString("archive.year", comment: ""), active: false, action: { onYearTap() })
                Spacer()
            }
        }
    }

    private func viewToggleBtn(_ label: String, active: Bool, action: (() -> Void)?) -> some View {
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

    // MARK: — İstatistik özet satırı
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(summary.filledDays)", label: NSLocalizedString("archive.selectedDays", comment: ""))
            Divider().frame(height: 32).background(ONETokens.oneIvory)
            statCell(value: "\(summary.totalDays - summary.filledDays)", label: NSLocalizedString("archive.silentDays", comment: ""))
            Divider().frame(height: 32).background(ONETokens.oneIvory)
            let pct = summary.totalDays > 0
                ? Int(Double(summary.filledDays) / Double(summary.totalDays) * 100)
                : 0
            statCell(value: "%\(pct)", label: NSLocalizedString("archive.completion", comment: ""))
        }
        .padding(.vertical, 14)
        .background(ONETokens.onePaper.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ONETokens.oneSilver, lineWidth: 1))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .displayMD()
                .foregroundColor(ONETokens.oneInk)
            Text(label)
                .monoLabel()
                .foregroundColor(ONETokens.oneAsh)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: — Takvim kartı
    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Gün adları başlıkları
            weekdayHeader

            // Hücreler — summary.calendarCells doğru offset'i içeriyor
            let cells = summary.calendarCells

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        if let entry = summary.primaryEntry(for: date) {
                            let dayEntries = summary.allEntries(for: date)
                            let hasMultiple = dayEntries.count > 1

                            ZStack(alignment: .topTrailing) {
                                FilledDayCell(entry: entry, isToday: Calendar.current.isDateInToday(date))

                                // Multi-entry badge
                                if hasMultiple {
                                    Text("\(dayEntries.count)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 14, height: 14)
                                        .background(ONETokens.oneBrand)
                                        .clipShape(Circle())
                                        .offset(x: 2, y: -2)
                                }
                            }
                            .onTapGesture {
                                ONEHaptics.feelingSelected()
                                previewEntries = dayEntries
                                previewIndex   = 0
                                withAnimation(ONEAnimation.cardSpring) {
                                    showPreview = true
                                }
                            }
                                .opacity(appeared ? 1 : 0)
                                .scaleEffect(appeared ? 1 : 0.85)
                                .animation(ONEAnimation.cardSpring
                                    .delay(cellDelay(for: date)),
                                    value: appeared)
                        } else {
                            EmptyDayCell(dayNumber: Calendar.current.component(.day, from: date))
                        }
                    } else {
                        // Boş placeholder (ay başı offset veya ay sonu dolgu)
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(16)
        .background(ONETokens.onePaper.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ONETokens.oneSilver, lineWidth: 1))
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { d in
                Text(d)
                    .monoSM()
                    .foregroundColor(ONETokens.oneStone)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 4)
    }

    private func cellDelay(for date: Date) -> Double {
        let day = Calendar.current.component(.day, from: date)
        return Double(day - 1) * 0.012
    }

    // MARK: — Mood şeridi
    private var moodStripSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("archive.colorDistribution", comment: ""))
                .monoSM(tracking: 1.8)
                .foregroundColor(ONETokens.oneMist)

            MoodBarStrip(
                moodDistribution: summary.moodDistribution,
                filledDays: summary.filledDays
            )
        }
    }
}
