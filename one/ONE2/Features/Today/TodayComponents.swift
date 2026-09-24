//
//  TodayComponents.swift
//  ONE 2.0
//
//  Bugün ekranının parçaları (06 › Bugün ekranı): üst çubuk (seri, selamlama,
//  profil), ritüel kartları (CheckInCard) ve mood hapı.
//

import Foundation
import SwiftUI

// MARK: - Üst çubuk

/// Solda seri hapı (brand renkli mono sayı), ortada selamlama, sağda profil.
struct TodayTopBar: View {
    let streak: Int?
    let greeting: String
    let onProfile: () -> Void

    var body: some View {
        ZStack {
            Text(greeting)
                .displaySM()
                .foregroundColor(V3Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, V3Tokens.spacingXL5 * 2)
                .accessibilityAddTraits(.isHeader)
            HStack {
                if let streak {
                    StreakPill(count: streak)
                }
                Spacer(minLength: 0)
                V3TopBarIconButton(systemName: "person.crop.circle",
                                   label: NSLocalizedString("one2.tab.profile", comment: "ONE 2.0 tab"),
                                   action: onProfile)
            }
        }
        .padding(.horizontal, V3Tokens.barInset)
        .frame(minHeight: V3Tokens.minTouchTarget)
        .padding(.bottom, V3Tokens.spacingSM)
    }
}

/// Seri hapı: alev + mono sayı. Brand rengi Bugün'de yalnız burada.
struct StreakPill: View {
    let count: Int

    var body: some View {
        HStack(spacing: V3Tokens.spacingXS) {
            Image(systemName: "flame")
                .iconSM()
                .foregroundColor(V3Tokens.ink)
            Text(verbatim: "\(count)")
                .monoSM(weight: .semibold)
                .foregroundColor(V3Tokens.brand)
        }
        .padding(.horizontal, V3Tokens.spacingMD)
        .frame(minHeight: V3Tokens.minTouchTarget)
        .background(Capsule(style: .continuous).fill(V3Tokens.wash))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(RitualCopy.streak(count))
    }
}

// MARK: - Ritüel alanı

/// Günlük mod: tek kart. Sabah+akşam: iki kart yatay sayfalı, sağdakinin
/// 16pt'si görünür (sıra `TodayRules.ordered`).
struct RitualArea: View {
    let layout: RitualLayout
    let cards: [RitualCardViewData]
    let onStart: (FlowKind) -> Void

    static let peek: CGFloat = V3Tokens.spacingLG

    var body: some View {
        switch layout {
        case .daily:
            ForEach(cards) { RitualCardView(card: $0, onStart: onStart) }
        case .morningEvening:
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: V3Tokens.spacingMD) {
                    ForEach(cards) { card in
                        RitualCardView(card: card, onStart: onStart)
                            .containerRelativeFrame(.horizontal) { length, _ in
                                length - Self.peek - V3Tokens.spacingMD
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }
}

/// CheckInCard: başlamadı · yarıda · tamam · kaçırıldı.
struct RitualCardView: View {
    let card: RitualCardViewData
    let onStart: (FlowKind) -> Void

    static let minHeight: CGFloat = 300

    private var isMissed: Bool { card.state == .missed }

    var body: some View {
        VStack(spacing: V3Tokens.spacingLG) {
            header
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
        .padding(V3Tokens.spacingXL)
        .frame(maxWidth: .infinity, minHeight: Self.minHeight)
        .overlay(
            RoundedRectangle(cornerRadius: V3Tokens.radiusTile, style: .continuous)
                .strokeBorder(V3Tokens.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(card.title)
                .displaySM()
                .foregroundColor(isMissed ? V3Tokens.mutedText : V3Tokens.ink)
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: V3Tokens.spacingSM)
            if card.state == .notStarted || isMissed {
                Text(card.durationLabel)
                    .monoSM()
                    .foregroundColor(V3Tokens.faintText)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch card.state {
        case .notStarted:
            V3PrimaryButton(title: NSLocalizedString("one2.ritual.start", comment: "Start a flow"), isFullWidth: true) {
                onStart(card.flow)
            }
        case .inProgress(let step, let total):
            VStack(spacing: V3Tokens.spacingMD) {
                FlowProgressLine(completed: step, total: total)
                V3PrimaryButton(title: RitualCopy.resume(step: step, total: total), isFullWidth: true) {
                    onStart(card.flow)
                }
            }
        case .done(let echo, let mood, let summary):
            VStack(spacing: V3Tokens.spacingMD) {
                if !echo.isEmpty {
                    Text(echo)
                        .font(V3Typography.quote(22))
                        .italic()
                        .foregroundColor(V3Tokens.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let mood { MoodPillView(mood: mood) }
                if let summary {
                    Text(summary)
                        .bodySM()
                        .foregroundColor(V3Tokens.mutedText)
                }
            }
        case .missed:
            Button { onStart(card.flow) } label: {
                Text(NSLocalizedString("one2.ritual.missed", comment: "Do the missed morning flow anyway"))
                    .bodyMDSemibold()
                    .underline()
                    .foregroundColor(V3Tokens.ink)
                    .frame(minHeight: V3Tokens.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.onePressable)
        }
    }
}

/// Adım ilerlemesi: `total` ince çizgi, ilk `completed` tanesi dolu. Hem
/// kartın yarıda durumunda hem akış kabuğunun üstünde.
struct FlowProgressLine: View {
    let completed: Int
    let total: Int

    var body: some View {
        HStack(spacing: V3Tokens.spacingXS) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < completed ? V3Tokens.ink : V3Tokens.hairline)
                    .frame(height: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String.localizedStringWithFormat(
            NSLocalizedString("one2.flow.progress", comment: "Step x of y"), min(completed + 1, total), total))
    }
}

// MARK: - Mood hapı

/// Skor diski (rakamlı, `score-N`) + etiket + duygular.
struct MoodPillView: View {
    let mood: MoodPillViewData

    static let diskSize: CGFloat = 28

    var body: some View {
        HStack(spacing: V3Tokens.spacingSM) {
            ZStack {
                Circle().fill(V3Tokens.score(mood.score))
                Text(verbatim: "\(mood.score)")
                    .bodySMSemibold()
                    .foregroundColor(V3Tokens.onScore(mood.score))
            }
            .frame(width: Self.diskSize, height: Self.diskSize)
            Text(mood.label)
                .bodySMMedium()
                .foregroundColor(V3Tokens.ink)
            if !mood.emotions.isEmpty {
                Text(mood.emotions.joined(separator: ", "))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, V3Tokens.spacingXS)
        .padding(.leading, V3Tokens.spacingXS)
        .padding(.trailing, V3Tokens.spacingMD)
        .background(Capsule(style: .continuous).fill(V3Tokens.wash))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(([ "\(mood.score), \(mood.label)"] + mood.emotions).joined(separator: ", "))
    }
}
