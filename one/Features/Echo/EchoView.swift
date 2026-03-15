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


    init(context: NSManagedObjectContext) {
        self.context = context
        _vm = StateObject(wrappedValue: EchoViewModel(context: context))
    }

    var body: some View {
        ZStack {
            ONETokens.oneCream.ignoresSafeArea()

            if vm.isLoading {
                loadingView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                            .padding(.top, 56)
                            .padding(.horizontal, 24)

                        // ── Bölümler — sosyal proof önce ──
                        sectionCard { weekSection }
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
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.15)) { appeared = true }
        }
    }

    // MARK: — Loading
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(ONETokens.oneAsh)
            Text("Yankı hazırlanıyor…")
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
        .background(Color.white.opacity(0.72))
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
            Text("Yankı")
                .displayLG()
                .foregroundColor(ONETokens.oneInk)

            Text("Mood geçmişin, alışkanlıkların ve çevrenle kesişen anların burada.")
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)
        }
        .padding(.bottom, 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .animation(.easeOut(duration: ONEAnimation.durationMedium).delay(0.0), value: appeared)
    }

    // MARK: — Hafta Bölümü
    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            label("Bu hafta")

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
                    Text("Bu hafta en çok bu his ağır bastı.")
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
        ["Pt","Sa","Ça","Pe","Cu","Ct","Pz"][idx % 7]
    }

    // MARK: — Tekrar Eden Şarkılar
    private var repeatedSongsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            label("Tekrar eden şarkılar")

            if vm.data.repeatedSongs.isEmpty {
                emptyNote("Bu hafta hiç tekrar eden şarkı yok.")
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
            label("Ne zaman seçiyorsun?")

            HStack(alignment: .center, spacing: 24) {
                HourRingView(distribution: vm.data.hourDistribution)
                    .frame(width: 112, height: 112)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.85)
                    .animation(ONEAnimation.cardSpring.delay(0.2), value: appeared)

                VStack(alignment: .leading, spacing: 10) {
                    timeRow(icon: "sunrise.fill",  label: "Sabah", hours: [6,7,8,9,10],   color: ONETokens.moodYellow)
                    timeRow(icon: "sun.max.fill",   label: "Öğlen", hours: [11,12,13,14], color: ONETokens.moodOrange)
                    timeRow(icon: "moon.fill",      label: "Akşam", hours: [18,19,20,21], color: ONETokens.oneBlue)
                    timeRow(icon: "moon.stars.fill", label: "Gece", hours: [22,23,0,1,2], color: ONETokens.moodPurple)
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
            Text("\(count) seçim")
                .font(ONETypography.bodyXS)
                .foregroundColor(ONETokens.oneInk)
        }
    }

    // MARK: — En Uzun Seri
    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            label("En uzun seri")

            if vm.data.longestStreak.days == 0 {
                emptyNote("Henüz bir seri oluşmadı.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    // Büyük sayı
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(vm.data.longestStreak.days)")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundColor(ONETokens.oneInk)
                            .tracking(-1.5)
                        Text("gün")
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
                label("Çevre ile")
                Spacer()
                if vm.isSyncLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            // Özet sayı
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(vm.data.syncCount)")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(ONETokens.oneInk)
                Text(vm.data.syncCount == 1 ? "kez çevrenle aynı şarkıda buluştun." : "kez çevrenle aynı şarkıda buluştun.")
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
                        Text("ve \(vm.data.circleSyncMatches.count - 5) eşleşme daha")
                            .monoSM(tracking: 0.5)
                            .foregroundColor(ONETokens.oneMist)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 2)
                    }
                }
            } else if !vm.isSyncLoading {
                // Boş durum
                Text("Henüz çevrenizden kimseyle aynı şarkıyı seçmediniz.")
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
