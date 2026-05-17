//
//  DailyReflectionCard.swift
//  one
//
//  B2 — Variable reward "Bugünün Yansıması". Aynı deneyim retention'ı
//  öldürür: her gün farklı bir mikro-deneyim sunmak habit loop'un
//  variable reward halkasını kapatır.
//
//  Gün dağılımı:
//  - Pazartesi  → kısa bir alıntı
//  - Salı       → çevre nabzı (anonim mood pulse)
//  - Çarşamba   → "7 gün önce bugün" (lastWeekEntry varsa)
//  - Perşembe   → bugünkü mood'a göre keşif ipucu
//  - Cuma       → haftanın renk şeridi önizlemesi
//  - Cumartesi  → hafta sonu vibe — yumuşak ton
//  - Pazar      → mini hafta yansıması
//

import SwiftUI

struct DailyReflectionCard: View {
    let todayEntry: DailyEntry
    let lastWeekEntry: DailyEntry?
    var showLastWeekReflection: Bool = false
    var onDismissLastWeek: () -> Void = {}

    private var weekday: Int {
        Calendar.current.component(.weekday, from: Date())
    }

    var body: some View {
        Group {
            switch weekday {
            case 2:  reflection(eyebrow: "PAZARTESİ", title: mondayQuote, icon: "quote.opening")
            case 3:  reflection(eyebrow: "SALI", title: tuesdayPulse, icon: "waveform")
            case 4:
                if let last = lastWeekEntry, showLastWeekReflection {
                    ZStack(alignment: .topTrailing) {
                        weekAgoCard(last)
                        Button {
                            withAnimation(ONEAnimation.micro) { onDismissLastWeek() }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(ONETokens.oneAsh)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .padding(.top, 6)
                        .padding(.trailing, 6)
                    }
                } else {
                    reflection(eyebrow: "ÇARŞAMBA", title: "Hafta ortası — yarıyı geçtin.", icon: "circle.lefthalf.filled")
                }
            case 5:  reflection(eyebrow: "PERŞEMBE", title: thursdayDiscoverHint, icon: "sparkles")
            case 6:  reflection(eyebrow: "CUMA", title: "Hafta kapanıyor — pazartesinin tonu farklıydı.", icon: "calendar.badge.clock")
            case 7:  reflection(eyebrow: "CUMARTESİ", title: "Hafta sonu vibe'ı — kendine yer aç.", icon: "leaf")
            case 1:  reflection(eyebrow: "PAZAR", title: "Bu hafta nasıl geçti?", icon: "moon.stars")
            default: reflection(eyebrow: "BUGÜN", title: "Bir kelime, bir his.", icon: "circle")
            }
        }
    }

    // MARK: - Day-specific copy

    private var mondayQuote: String {
        let quotes = [
            "“Hisset, kaydet, devam et.”",
            "“Hafta yumuşak başlasın — küçük bir mood yeter.”",
            "“Dün dündü. Bugün bugün.”"
        ]
        // Tarih bazlı deterministik seçim (bir günde stabil)
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return quotes[day % quotes.count]
    }

    private var tuesdayPulse: String {
        // Çevre mood'u (varsa) — gerçek veriye bağlanması ileride; şimdilik
        // soft anonim formülasyon.
        "Çevren bugün benzer bir ton seçti."
    }

    private var thursdayDiscoverHint: String {
        let mood = todayEntry.normalizedMoodLabel
        return "‘\(mood)’ için Keşfet'te bir şey var."
    }

    // MARK: - Layout helpers

    private func reflection(eyebrow: String, title: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(todayEntry.moodColor.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(todayEntry.moodColor.opacity(0.95))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .monoLabel(tracking: 1.2)
                    .foregroundColor(ONETokens.oneAsh)
                Text(title)
                    .bodySMMedium()
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(3)
                    .lineSpacing(2)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.oneCreamMid.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ONETokens.oneSilver, lineWidth: 1)
                )
        )
    }

    private func weekAgoCard(_ entry: DailyEntry) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(entry.moodColor)
                .frame(width: 10, height: 10)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("ÇARŞAMBA · 7 gün önce")
                    .monoLabel(tracking: 1.0)
                    .foregroundColor(ONETokens.oneAsh)
                Text(entry.songName)
                    .bodySMMedium()
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(2)
                Text(entry.artistName)
                    .monoSM(tracking: 0)
                    .foregroundColor(ONETokens.oneCharcoal)
                    .lineLimit(1)
            }

            Spacer()

            Text(entry.normalizedMoodLabel.uppercased())
                .monoLabel(tracking: 1.0)
                .foregroundColor(entry.moodColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(entry.moodColor.opacity(0.12)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ONETokens.onePaper)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ONETokens.oneSilver, lineWidth: 1)
                )
        )
    }
}
