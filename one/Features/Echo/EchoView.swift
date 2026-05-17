//
//  EchoView.swift
//  One - Günlük Mood
//
//  UX redesign: kart tabanlı düzen, net tipografi hiyerarşisi,
//  okunabilir font boyutları, sosyal ürün dili tutarlılığı.
//

import SwiftUI
import CoreData

struct EchoView: View {
    @StateObject private var vm: EchoViewModel
    @State private var appeared = false
    private let context: NSManagedObjectContext
    var onDismiss: (() -> Void)? = nil

    init(context: NSManagedObjectContext, onDismiss: (() -> Void)? = nil) {
        self.context = context
        self.onDismiss = onDismiss
        _vm = StateObject(wrappedValue: EchoViewModel(context: context))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ONETokens.oneCream.ignoresSafeArea()

            if vm.isLoading {
                loadingView
            } else if vm.data.totalSongs == 0 {
                // A5 — Echo'da hiç data yok: zenginleştirme yerine ilk adımı öner
                echoEmptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.top, onDismiss != nil ? 90 : 56)
                            .padding(.horizontal, 24)

                        // ── Bu Ay / Tüm Zamanlar toggle ──
                        periodToggle
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        // ── Bölümler — sosyal proof önce ──
                        sectionCard { statsSection }
                        sectionCard { weekSection }
                        sectionCard { moodDistributionSection }
                        if vm.data.syncCount > 0 {
                            sectionCard { syncSection }
                        }
                        sectionCard { repeatedSongsSection }
                        sectionCard { hourSection }
                        sectionCard { streakSection }

                        Spacer().frame(height: 100)
                    }
                }
            }

            // Fixed back button (outside ScrollView)
            if let onDismiss {
                Button(action: onDismiss) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text(NSLocalizedString("echo.backToProfile", comment: ""))
                            .bodySMMedium()
                    }
                    .foregroundColor(ONETokens.oneInk)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(ONETokens.onePaper.opacity(0.9))
                            .overlay(Capsule().stroke(ONETokens.oneSilver, lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                    )
                }
                .padding(.top, 54)
                .padding(.leading, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.15)) { appeared = true }
        }
    }

    // MARK: — Empty state (A5)
    /// Echo'da hiç entry yok — kullanıcıya ilk somut next-action'ı öner.
    private var echoEmptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(ONETokens.oneSilver, lineWidth: 1.2)
                    .frame(width: 78, height: 78)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(ONETokens.oneAsh)
            }

            VStack(spacing: 8) {
                Text(NSLocalizedString("echo.empty.title", comment: ""))
                    .displayMD()
                    .foregroundColor(ONETokens.oneInk)
                    .multilineTextAlignment(.center)
                Text(NSLocalizedString("echo.empty.body", comment: ""))
                    .bodySM()
                    .foregroundColor(ONETokens.oneAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }

            Button {
                if let onDismiss {
                    onDismiss()
                }
                NotificationCenter.default.post(name: .init("switchToTodayTab"), object: nil)
            } label: {
                Text(NSLocalizedString("echo.empty.cta", comment: ""))
                    .monoSM(tracking: 0.8)
                    .foregroundColor(ONETokens.oneCream)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(ONETokens.oneInk))
            }
            .padding(.top, 6)

            Spacer()
            Spacer().frame(height: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: — Loading
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(ONETokens.oneAsh)
            Text(NSLocalizedString("echo.loading", comment: ""))
                .font(ONETypography.bodyXS)
                .italic()
                .foregroundColor(ONETokens.oneAsh)
        }
    }

    // MARK: — Kart sarmalayıcı
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ONETokens.onePaper.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(ONETokens.oneSilver, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: — Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("echo.title", comment: ""))
                .displayLG()
                .foregroundColor(ONETokens.oneInk)

            Text(NSLocalizedString("echo.subtitle", comment: ""))
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)
        }
        .padding(.bottom, 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.0), value: appeared)
    }

    // MARK: — Period Toggle
    private var periodToggle: some View {
        HStack(spacing: 0) {
            periodBtn(NSLocalizedString("echo.thisMonth", comment: ""), isSelected: vm.showThisMonth) {
                withAnimation(.easeInOut(duration: 0.18)) { vm.showThisMonth = true }
            }
            periodBtn(NSLocalizedString("echo.allTime", comment: ""), isSelected: !vm.showThisMonth) {
                withAnimation(.easeInOut(duration: 0.18)) { vm.showThisMonth = false }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ONETokens.oneSilver.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(ONETokens.oneSilver, lineWidth: 1))
        )
    }

    private func periodBtn(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .monoSM(tracking: 0.6)
                .foregroundColor(isSelected ? ONETokens.oneCream : ONETokens.oneAsh)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(isSelected ? ONETokens.oneInk : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(3)
    }

    // MARK: — Genel İstatistikler
    private var statsSection: some View {
        let songCount = vm.showThisMonth ? vm.data.thisMonthSongs : vm.data.totalSongs
        let songLabel = vm.showThisMonth ? NSLocalizedString("echo.stats.thisMonth", comment: "") : NSLocalizedString("echo.stats.allTime", comment: "")
        return VStack(alignment: .leading, spacing: 14) {
            label(songLabel)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statTile(value: "\(songCount)", unit: NSLocalizedString("echo.stats.songs", comment: ""),
                         icon: "music.note", color: ONETokens.oneBrand)
                statTile(value: "\(vm.data.currentStreak)", unit: NSLocalizedString("echo.stats.streakDays", comment: ""),
                         icon: "flame.fill", color: ONETokens.moodOrange)
                if let day = vm.data.mostActiveDayOfWeek {
                    statTile(value: day, unit: NSLocalizedString("echo.stats.mostActive", comment: ""),
                             icon: "calendar", color: ONETokens.oneBlue)
                }
                if !vm.showThisMonth {
                    let avg = vm.data.averageSongsPerMonth
                    let avgStr = avg >= 10 ? String(Int(avg.rounded())) : String(format: "%.1f", avg)
                    statTile(value: avgStr, unit: NSLocalizedString("echo.stats.monthlyAvg", comment: ""),
                             icon: "chart.bar.fill", color: ONETokens.oneGreen)
                }
            }
        }
    }

    private func statTile(value: String, unit: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .displaySM()
                    .fontWeight(.semibold)
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .monoLabel(tracking: 0.4)
                    .foregroundColor(ONETokens.oneAsh)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ONETokens.oneSilver.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: — Mood Dağılımı
    private var moodDistributionSection: some View {
        let moods = vm.showThisMonth ? vm.data.thisMonthMoodDistribution : vm.data.moodDistribution
        let topMoods = Array(moods.prefix(6))
        let maxCount = topMoods.map(\.count).max() ?? 1

        return VStack(alignment: .leading, spacing: 14) {
            label(NSLocalizedString("echo.moodDistribution", comment: ""))

            if topMoods.isEmpty {
                emptyNote(NSLocalizedString("echo.noData", comment: ""))
            } else {
                VStack(spacing: 8) {
                    ForEach(topMoods) { mood in
                        HStack(spacing: 10) {
                            Text(mood.label)
                                .monoSM(tracking: 0.3)
                                .foregroundColor(ONETokens.oneAsh)
                                .frame(width: 72, alignment: .leading)
                                .lineLimit(1)

                            GeometryReader { geo in
                                let barWidth = geo.size.width * CGFloat(mood.count) / CGFloat(maxCount)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(ONETokens.oneSilver.opacity(0.6))
                                        .frame(maxWidth: .infinity)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: mood.colorHex))
                                        .frame(width: max(barWidth, 8))
                                }
                            }
                            .frame(height: 10)

                            Text("\(mood.count)")
                                .monoSM(tracking: 0)
                                .foregroundColor(ONETokens.oneCharcoal)
                                .frame(width: 28, alignment: .trailing)
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.1), value: appeared)
                    }
                }
            }
        }
    }

    // MARK: — Hafta Bölümü
    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            label(NSLocalizedString("echo.thisWeek", comment: ""))

            // 7 renk kutusu
            HStack(spacing: 5) {
                ForEach(Array(vm.data.weekColors.enumerated()), id: \.offset) { idx, color in
                    VStack(spacing: 4) {
                        if let color {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(color)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .opacity(appeared ? 1 : 0)
                                .scaleEffect(y: appeared ? 1 : 0.2, anchor: .bottom)
                                .animation(
                                    ONEAnimation.cardSpring
                                    .delay(Double(idx) * 0.05 + 0.1),
                                    value: appeared
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(
                                    ONETokens.oneCreamMid,
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .opacity(0.5)
                        }
                        // gün etiketi: Pt Sa Ça Pe Cu Ct Pz
                        Text(weekDayLabel(idx))
                            .monoLabel()
                            .foregroundColor(ONETokens.oneMist)
                    }
                }
            }

            // Baskın his
            if let feeling = vm.data.dominantFeeling {
                HStack(spacing: 8) {
                    FeelingIconView(type: feeling)
                        .frame(width: 26, height: 20)
                        .opacity(0.55)
                    Text(NSLocalizedString("echo.dominantFeeling", comment: ""))
                        .bodyXS()
                        .foregroundColor(ONETokens.oneAsh)
                }
                .padding(.top, 2)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.5), value: appeared)
            }
        }
    }

    // Pazar = 0 başlıyorsa üste düşer diye idx = Mon-first
    private func weekDayLabel(_ idx: Int) -> String {
        (["calendar.day.mon", "calendar.day.tue", "calendar.day.wed",
           "calendar.day.thu", "calendar.day.fri", "calendar.day.sat", "calendar.day.sun"]
            .map { NSLocalizedString($0, comment: "") })[idx % 7]
    }

    // MARK: — Tekrar Eden Şarkılar
    private var repeatedSongsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            label(NSLocalizedString("echo.repeatedSongs", comment: ""))

            if vm.data.repeatedSongs.isEmpty {
                emptyNote(NSLocalizedString("echo.noRepeatedSongs", comment: ""))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.data.repeatedSongs.enumerated()), id: \.element.id) { idx, song in
                        songRow(song, idx: idx)
                        if idx < vm.data.repeatedSongs.count - 1 {
                            Divider()
                                .background(ONETokens.oneCream)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    private func songRow(_ song: RepeatedSong, idx: Int) -> some View {
        HStack(spacing: 12) {
            // Renk şeridi
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: song.moodColorHex).opacity(0.85))
                .frame(width: 3, height: 40)

            // İsim + Sanatçı
            VStack(alignment: .leading, spacing: 3) {
                Text(song.songName)
                    .bodyMD()
                    .fontWeight(.medium)
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
                Text(song.artistName)
                    .monoSM()
                    .foregroundColor(ONETokens.oneAsh)
                    .lineLimit(1)
            }

            Spacer()

            // Sayaç + tarihler
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(song.count)×")
                    .font(ONETypography.displaySM)
                    .foregroundColor(ONETokens.oneInk)
                Text(song.dates.prefix(3).joined(separator: " · "))
                    .monoBase()
                    .foregroundColor(ONETokens.oneCharcoal)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 10)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 14)
        .animation(
            ONEAnimation.panelSpring
            .delay(Double(idx) * 0.08 + 0.15),
            value: appeared
        )
    }

    // MARK: — Saat Dağılımı
    private var hourSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            label(NSLocalizedString("echo.whenPick", comment: ""))

            HStack(alignment: .center, spacing: 24) {
                HourRingView(distribution: vm.data.hourDistribution)
                    .frame(width: 112, height: 112)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .animation(ONEAnimation.cardSpring.delay(0.2), value: appeared)

                VStack(alignment: .leading, spacing: 10) {
                    timeRow(icon: "sunrise.fill",  label: NSLocalizedString("echo.time.morning", comment: ""), hours: [6,7,8,9,10],   color: ONETokens.moodYellow)
                    timeRow(icon: "sun.max.fill",   label: NSLocalizedString("echo.time.noon", comment: ""), hours: [11,12,13,14], color: ONETokens.moodOrange)
                    timeRow(icon: "moon.fill",      label: NSLocalizedString("echo.time.evening", comment: ""), hours: [18,19,20,21], color: ONETokens.oneBlue)
                    timeRow(icon: "moon.stars.fill", label: NSLocalizedString("echo.time.night", comment: ""), hours: [22,23,0,1,2], color: ONETokens.moodPurple)
                }
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.35), value: appeared)
            }
        }
    }

    private func timeRow(icon: String, label: String, hours: [Int], color: Color) -> some View {
        let count = hours.reduce(0) { $0 + (vm.data.hourDistribution[$1] ?? 0) }
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 16)
            Text(label)
                .monoSM()
                .foregroundColor(ONETokens.oneAsh)
                .frame(width: 40, alignment: .leading)
            Text(String(format: NSLocalizedString("echo.selections", comment: ""), count))
                .font(ONETypography.bodyXS)
                .foregroundColor(ONETokens.oneInk)
        }
    }

    // MARK: — En Uzun Seri
    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            label(NSLocalizedString("echo.longestStreak", comment: ""))

            if vm.data.longestStreak.days == 0 {
                emptyNote(NSLocalizedString("echo.noStreak", comment: ""))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    // Büyük sayı
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(vm.data.longestStreak.days)")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundColor(ONETokens.oneInk)
                            .tracking(-1.5)
                        Text(NSLocalizedString("echo.days", comment: ""))
                            .displayXS()
                            .foregroundColor(ONETokens.oneAsh)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(ONEAnimation.cardSpring.delay(0.2), value: appeared)

                    // Tarih aralığı
                    Text("\(vm.data.longestStreak.startDate)  →  \(vm.data.longestStreak.endDate)")
                        .monoSM()
                        .foregroundColor(ONETokens.oneCharcoal)

                    // Renk şeridi
                    if !vm.data.longestStreak.colors.isEmpty {
                        HStack(spacing: 3) {
                            ForEach(Array(vm.data.longestStreak.colors.enumerated()), id: \.offset) { _, color in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color)
                                    .frame(height: 10)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: ONEAnimation.durationLong).delay(0.4), value: appeared)
                    }
                }
            }
        }
    }

    // MARK: — Çevre Eşleşmesi
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Başlık + loading
            HStack {
                label(NSLocalizedString("echo.circle", comment: ""))
                Spacer()
                if vm.isSyncLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            // Özet sayı
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(vm.data.syncCount)")
                    .displayXL()
                    .fontWeight(.semibold)
                    .foregroundColor(ONETokens.oneInk)
                Text(NSLocalizedString("echo.circleMatches", comment: ""))
                    .bodyMD()
                    .foregroundColor(ONETokens.oneAsh)
            }

            // Eşleşme listesi
            if !vm.data.circleSyncMatches.isEmpty {
                VStack(spacing: 8) {
                    ForEach(vm.data.circleSyncMatches.prefix(5)) { match in
                        HStack(spacing: 12) {
                            // Mood rengi dot
                            Circle()
                                .fill(Color(hex: match.moodColorHex))
                                .frame(width: 10, height: 10)

                            // Şarkı + sanatçı
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.songName)
                                    .bodyMD()
                                    .foregroundColor(ONETokens.oneInk)
                                    .lineLimit(1)
                                Text(match.artistName)
                                    .monoSM(tracking: 0)
                                    .foregroundColor(ONETokens.oneAsh)
                            }

                            Spacer()

                            // Arkadaş + tarih
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(match.friendDisplayName)
                                    .monoSM(tracking: 0.4)
                                    .foregroundColor(ONETokens.oneInk)
                                Text(match.dateLabel)
                                    .monoSM(tracking: 0)
                                    .foregroundColor(ONETokens.oneMist)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ONETokens.oneSilver)
                        )
                    }

                    // 5'ten fazlası varsa "ve X daha"
                    if vm.data.circleSyncMatches.count > 5 {
                        Text(String(format: NSLocalizedString("echo.moreMatches", comment: ""), vm.data.circleSyncMatches.count - 5))
                            .monoSM(tracking: 0.5)
                            .foregroundColor(ONETokens.oneMist)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 2)
                    }
                }
            } else if !vm.isSyncLoading {
                // Boş durum
                Text(NSLocalizedString("echo.noCircleMatches", comment: ""))
                    .monoSM(tracking: 0.3)
                    .foregroundColor(ONETokens.oneMist)
                    .padding(.top, 2)
            }
        }
    }


    // MARK: — Yardımcılar
    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .monoSM(tracking: 1.8)
            .foregroundColor(ONETokens.oneMist)
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .bodySM()
            .foregroundColor(ONETokens.oneAsh)
    }
}

// MARK: — HourRingView
private struct HourRingView: View {
    let distribution: [Int: Int]

    var body: some View {
        Canvas { ctx, size in
            let cx       = Double(size.width)  / 2.0
            let cy       = Double(size.height) / 2.0
            let minSide  = min(Double(size.width), Double(size.height))
            let radius   = minSide / 2.0 - 6.0
            let maxCount = Double(max(1, distribution.values.max() ?? 1))

            for hour in 0..<24 {
                let count   = Double(distribution[hour] ?? 0)
                let angle   = (Double(hour) / 24.0) * 2.0 * Double.pi - Double.pi / 2.0
                let barLen  = (count / maxCount) * 16.0 + (count > 0 ? 4.0 : 0.0)
                let r1      = radius - 2.0
                let r2      = radius + barLen
                let ix      = cx + r1 * Foundation.cos(angle)
                let iy      = cy + r1 * Foundation.sin(angle)
                let ox      = cx + r2 * Foundation.cos(angle)
                let oy      = cy + r2 * Foundation.sin(angle)

                var path = Path()
                path.move(to:    CGPoint(x: ix, y: iy))
                path.addLine(to: CGPoint(x: ox, y: oy))

                let alpha: Double = count > 0 ? 0.80 : 0.10
                let isNight       = hour < 6 || hour >= 22
                let clr: Color    = isNight
                    ? ONETokens.moodPurple.opacity(alpha)
                    : ONETokens.moodYellow.opacity(alpha)
                ctx.stroke(path, with: .color(clr), lineWidth: 2.8)
            }

            // İç halka
            let rInner = radius - 2.0
            let ringRect = CGRect(
                x: cx - rInner, y: cy - rInner,
                width: rInner * 2.0, height: rInner * 2.0
            )
            ctx.stroke(
                Path(ellipseIn: ringRect),
                with: .color(ONETokens.oneSilver),
                lineWidth: 1.0
            )
        }
    }
}

#Preview {
    EchoView(context: PersistenceController.preview.container.viewContext)
}
