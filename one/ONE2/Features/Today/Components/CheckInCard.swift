//
//  CheckInCard.swift
//  ONE 2.0
//
//  Bugün'ün kahramanı (components/CheckInCard.md, `.o-checkin`): `ground`
//  zemin, 1px `line`, `radius-lg`, en az 300pt, içerik ortalı.
//  - Check-in var: yankı cümlesi (`affirmation`, `ink-muted`) + mood hapı.
//  - Yok, yazılabilir: "Şu an nasılsın?" + `ScoreScale`.
//  - Yok, yazılamaz (7 günden eski geçmiş gün): tek satır bilgi.
//  Sabah+akşam modunda kartlar yatay sayfalanır; bir sonraki kartın 16pt'si
//  görünür, sayfa göstergesi yok (`CheckInPager`).
//

import SwiftUI

struct CheckInCard: View {
    let data: CheckInCardData
    /// Sabah+akşam modunda kartın üstünde yuva etiketi.
    var showsSlot = false
    /// Boş kartta skor ölçeği gösterilsin mi (bugün ya da doldurulabilir gün).
    var canCheckIn = true
    /// Geçmiş gün: soru "O gün nasıldın?".
    var isPast = false
    let onScore: (Int) -> Void
    let onOpen: () -> Void

    var body: some View {
        ONE2OutlineCard(padding: ONE2Space.s4, minHeight: ONE2Size.checkInCardMin) {
            VStack(spacing: ONE2Space.s8) {
                if showsSlot, let slot = slotTitle {
                    ONE2Label(slot)
                }
                content
            }
            .padding(.vertical, ONE2Space.s4)
        }
    }

    @ViewBuilder private var content: some View {
        if let summary = data.summary {
            if let echo = summary.echo {
                Text(echo)
                    .one2Type(.affirmation)
                    .foregroundStyle(ONE2Color.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ONE2Space.s2)
            }
            Button(action: onOpen) {
                MoodPill(score: summary.score)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.one2Press)
        } else if canCheckIn {
            Text(one2String(isPast ? "one2.today.checkIn.questionPast" : "one2.today.checkIn.question"))
                .one2Type(.title)
                .foregroundStyle(ONE2Color.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            ScoreScale(onSelect: onScore)
        } else {
            Text(one2String("one2.today.checkIn.noEntry"))
                .one2Type(.body)
                .foregroundStyle(ONE2Color.inkMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var slotTitle: String? {
        switch data.slot {
        case .morning: return one2String("one2.today.slot.morning")
        case .evening: return one2String("one2.today.slot.evening")
        case .daily:   return nil
        }
    }
}

/// Bir ya da iki check-in kartı. İki kartta yatay sayfalı.
struct CheckInPager: View {
    let cards: [CheckInCardData]
    var canCheckIn = true
    var isPast = false
    let onScore: (CheckInCardData, Int) -> Void
    let onOpen: (CheckInCardData) -> Void

    var body: some View {
        if cards.count == 1, let card = cards.first {
            cardView(card, showsSlot: false)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: ONE2Space.cardGap) {
                    ForEach(cards) { card in
                        cardView(card, showsSlot: true)
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

    private func cardView(_ card: CheckInCardData, showsSlot: Bool) -> some View {
        CheckInCard(
            data: card,
            showsSlot: showsSlot,
            canCheckIn: canCheckIn,
            isPast: isPast,
            onScore: { onScore(card, $0) },
            onOpen: { onOpen(card) }
        )
    }
}

#if DEBUG
private struct CheckInCardSamples: View {
    var body: some View {
        VStack(spacing: ONE2Space.s5) {
            CheckInPager(cards: TodayFixture.many.checkIns, onScore: { _, _ in }, onOpen: { _ in })
            CheckInPager(cards: TodayFixture.few.checkIns, onScore: { _, _ in }, onOpen: { _ in })
            CheckInPager(cards: TodayFixture.morningEvening.checkIns, onScore: { _, _ in }, onOpen: { _ in })
            CheckInPager(cards: TodayFixture.few.checkIns, canCheckIn: false, onScore: { _, _ in }, onOpen: { _ in })
        }
    }
}

#Preview("Gece") { CheckInCardSamples().one2Preview(.gece) }
#Preview("Gün") { CheckInCardSamples().one2Preview(.gun) }
#Preview("AX3") { CheckInCardSamples().one2Preview(.ax3) }
#endif
