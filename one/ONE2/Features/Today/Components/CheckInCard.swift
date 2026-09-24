//
//  CheckInCard.swift
//  ONE 2.0
//
//  Ritüel kartı (07 §5.1; components/CheckInCard.md zemini): `ground` zemin,
//  1px `line`, `radius-lg`, en az 300pt, içerik ortalı. Durumlar:
//  - Başlamadı: başlık + mono süre ("2 dk") + `Başla` (ekranın birincil eylemi).
//  - Yarıda: başlık + "Devam et · 3/5" + ilerleme çizgisi.
//  - Tamam: yankı (`affirmation`, `ink-muted`) + MoodPill + tek satır özet.
//  - Kaçırıldı: sönük başlık + "Yine de yap" (ikincil).
//  - Boş (7 günden eski geçmiş gün): "Bu güne kayıt yok."
//  Sabah+akşam modunda kartlar yatay sayfalanır; bir sonraki kartın 16pt'si
//  görünür, sayfa göstergesi yok (`CheckInPager`).
//

import SwiftUI

struct CheckInCard: View {
    let data: CheckInCardData
    /// Başla / Devam et / Yine de yap.
    let onStart: () -> Void
    /// Tamamlanmış kartta mood hapı → günün girdileri.
    let onOpen: () -> Void

    var body: some View {
        ONE2OutlineCard(padding: ONE2Space.s6, minHeight: ONE2Size.checkInCardMin) {
            VStack(spacing: ONE2Space.s6) {
                content
            }
            .multilineTextAlignment(.center)
            .padding(.vertical, ONE2Space.s2)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var content: some View {
        switch data.status {
        case .notStarted:
            header(muted: false)
            Button(action: onStart) {
                Text(one2String("one2.today.ritual.start")).contentShape(Rectangle())
            }
            .buttonStyle(.one2(.primary))

        case .inProgress(let step, let total):
            header(muted: false)
            VStack(spacing: ONE2Space.s4) {
                ProgressLine(fraction: Double(step - 1) / Double(max(total, 1)))
                Button(action: onStart) {
                    Text(String(format: one2String("one2.today.ritual.resume"), step, total))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.one2(.primary))
            }

        case .done(let summary, let detail):
            if let echo = summary.echo {
                Text(echo)
                    .one2Type(.affirmation)
                    .foregroundStyle(ONE2Color.inkMuted)
            }
            VStack(spacing: ONE2Space.s3) {
                Button(action: onOpen) {
                    MoodPill(score: summary.score).contentShape(Rectangle())
                }
                .buttonStyle(.one2Press)
                if let detail {
                    Text(detail)
                        .one2Type(.bodySm)
                        .foregroundStyle(ONE2Color.inkMuted)
                }
            }

        case .missed:
            header(muted: true)
            Button(action: onStart) {
                Text(one2String("one2.today.ritual.anyway")).contentShape(Rectangle())
            }
            .buttonStyle(.one2(.secondary))

        case .empty:
            Text(one2String("one2.today.ritual.empty"))
                .one2Type(.body)
                .foregroundStyle(ONE2Color.inkMuted)
        }
    }

    private func header(muted: Bool) -> some View {
        VStack(spacing: ONE2Space.s2) {
            Text(data.flow.title)
                .one2Type(.title)
                .foregroundStyle(muted ? ONE2Color.inkMuted : ONE2Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text(String(format: one2String("one2.today.ritual.minutes"), data.minutes))
                .one2Type(.time)
                .foregroundStyle(muted ? ONE2Color.inkFaint : ONE2Color.inkMuted)
        }
    }
}

/// Yarıdaki akışın ilerlemesi: `raised` zemin üstünde `ink` dolgu.
private struct ProgressLine: View {
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(ONE2Color.raised)
            .frame(height: ONE2Size.progressLine)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(ONE2Color.ink)
                        .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .accessibilityHidden(true)
    }
}

/// Bir ya da iki ritüel kartı. İki kartta yatay sayfalı.
struct CheckInPager: View {
    let cards: [CheckInCardData]
    let onStart: (CheckInCardData) -> Void
    let onOpen: (CheckInCardData) -> Void

    var body: some View {
        if cards.count == 1, let card = cards.first {
            cardView(card)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: ONE2Space.cardGap) {
                    ForEach(cards) { card in
                        cardView(card)
                            .containerRelativeFrame(.horizontal) { width, _ in
                                width - ONE2Size.pagePeek - ONE2Space.cardGap
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    private func cardView(_ card: CheckInCardData) -> some View {
        CheckInCard(data: card, onStart: { onStart(card) }, onOpen: { onOpen(card) })
    }
}

#if DEBUG
private struct CheckInCardSamples: View {
    var body: some View {
        VStack(spacing: ONE2Space.s5) {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, card in
                CheckInCard(data: card, onStart: {}, onOpen: {})
            }
            CheckInPager(cards: TodayFixture.morningEvening.checkIns, onStart: { _ in }, onOpen: { _ in })
        }
    }

    private var samples: [CheckInCardData] {
        [
            TodayFixture.dailyCard(.notStarted),
            TodayFixture.dailyCard(.inProgress(step: 3, total: 5)),
            TodayFixture.dailyCard(.done(TodayFixture.checkInEvening, detail: nil)),
            TodayFixture.eveningCard(.done(TodayFixture.checkInEvening, detail: "4/5 pratik")),
            TodayFixture.morningCard(.missed),
            TodayFixture.dailyCard(.empty),
        ]
    }
}

#Preview("Gece") { CheckInCardSamples().one2Preview(.gece) }
#Preview("Gün") { CheckInCardSamples().one2Preview(.gun) }
#Preview("AX3") { CheckInCardSamples().one2Preview(.ax3) }
#endif
