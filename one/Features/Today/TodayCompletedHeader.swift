//
//  TodayCompletedHeader.swift
//  one
//
//  Kaydedildi ekranının üst materyali: streak chip'i, "senin rengin: X"
//  hero'su, freeze şeridi ve haftalık ritim. `TodayCompletedView.swift`'ten
//  ayrıldı — ana kartın üstünde duran, karta bağlı olmayan blok.
//

import SwiftUI

struct CompletedHeroHeader: View {
    let entry: DailyEntry
    let streakDays: Int
    /// Count-up animasyonunun o anki değeri — parent'ın onAppear'ı sürüyor.
    let displayedStreak: Int
    /// Alev nabzı ölçeği — yine parent'ın count-up task'ı sürüyor.
    let streakFlamePulse: CGFloat
    let isFreezeActive: Bool
    let weekRhythm: [WeekRhythm.Day]
    let onBackfill: ((Date) -> Void)?
    /// GeometryReader'dan gelen kullanılabilir yükseklik — üst boşluklar
    /// buna göre ölçekleniyor.
    let available: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Milestone'da chip'in nefes alması — yalnız bu view'a ait, onAppear'da
    /// tetikleniyor.
    @State private var streakChipPulse: Bool = false

    /// Header top padding: scales 10–32 pt.
    private func headerTopPad(available: CGFloat) -> CGFloat {
        max(10, min(32, available * 0.038))
    }

    /// Header bottom padding: scales 8–16 pt.
    private func headerBottomPad(available: CGFloat) -> CGFloat {
        max(8, min(16, available * 0.02))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Prototipteki `.done-hero`: ortalanmış, mood rengiyle yukarıdan
            // aşağı sönen bir tint. Marka adı ("ONE+") burada değil — bu
            // ekranın konusu marka değil, o günün rengi. Streak chip'i kaldı
            // ama artık hero'nun üstünde.
            VStack(spacing: 0) {
                // v3: streak chip'i yasak (Section 9 — seri sayacı yok).
                Text(NSLocalizedString("today.doneLabel", comment: ""))
                    .monoLabel(tracking: 1.3)
                    .foregroundColor(V3Tokens.faintText)
                    .padding(.top, ONETokens.spacingLG)

                // "senin rengin: huzurlu" — mood adı kendi renginde.
                (
                    Text(NSLocalizedString("today.yourColourIs", comment: ""))
                        .foregroundColor(V3Tokens.ink)
                    + Text(entry.moodLabel.lowercased())
                        .foregroundColor(entry.moodColor)
                )
                .displayLG()
                .multilineTextAlignment(.center)
                .padding(.top, 9)

                Text(NSLocalizedString("today.seeYouTomorrow", comment: ""))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.top, 11)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, ONETokens.spacingXL2)
            .padding(.top, headerTopPad(available: available))
            .padding(.bottom, headerBottomPad(available: available))
            .background(
                // Prototip: hero'nun arkasında mood renginden şeffafa inen bir
                // gradyan. Ekranın geri kalanı krem kalır.
                LinearGradient(
                    colors: [entry.moodColor.opacity(0.14), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            if isFreezeActive {
                HStack(spacing: 8) {
                    Text("❄️")
                        .font(V3Typography.sans(13))
                    Text("Serin bugün donduruldu")
                        .monoSM(tracking: 0.5)
                        .foregroundColor(Color(hex: "#5B9BD5"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color(hex: "#5B9BD5").opacity(0.08))
                        .overlay(Capsule().stroke(Color(hex: "#5B9BD5").opacity(0.25), lineWidth: 1))
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ONETokens.spacingXL2)
                .padding(.bottom, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Faz 3 — haftalık ritim. Bugün dolu olsa da geçmiş boş günler
            // buradan telafi edilebilir.
            if !weekRhythm.isEmpty {
                WeekRhythmView(days: weekRhythm) { date in
                    onBackfill?(date)
                }
                .padding(.horizontal, ONETokens.spacingXL2)
                .padding(.bottom, 18)
            }
        }
    }
}
