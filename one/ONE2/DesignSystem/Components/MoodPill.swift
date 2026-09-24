//
//  MoodPill.swift
//  ONE 2.0
//
//  Mood hapı (`.o-moodpill`): küçük skor diski + etiket, isteğe bağlı
//  duygular ("Çok iyi · Minnettar").
//  - filled: raised zemin, ink-muted metin (Bugün check-in kartı)
//  - outline: şeffaf + 1px `line`, ink metin (Yolculuk geçmiş kartı)
//  Görünüm; tek öğe okunur ("5, Çok iyi, Minnettar").
//

import SwiftUI

struct MoodPill: View {
    enum Style: Sendable { case filled, outline }

    let score: Int
    var detail: String? = nil
    var style: Style = .filled

    private var text: String {
        [ONE2Score.label(score), detail].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: ONE2Size.moodPillGap) {
            ScoreDisc(score: score, size: .small)
            Text(text)
                .one2Type(.headline)
                .foregroundStyle(style == .filled ? ONE2Color.inkMuted : ONE2Color.ink)
        }
        .padding(.leading, ONE2Space.s3)
        .padding(.trailing, ONE2Size.pillPadding)
        .padding(.vertical, ONE2Space.s2)
        .frame(minHeight: ONE2Size.minTouch)
        .background(style == .filled ? ONE2Color.raised : .clear, in: Capsule())
        .overlay {
            if style == .outline {
                Capsule().strokeBorder(ONE2Color.line, lineWidth: ONE2Size.hairline)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text([ONE2Score.accessibilityLabel(score), detail].compactMap { $0 }.joined(separator: ", ")))
    }
}

#if DEBUG
private struct MoodPillSamples: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ONE2Space.s3) {
            MoodPill(score: 3)
            MoodPill(score: 5, detail: "Minnettar", style: .outline)
            MoodPill(score: 1, detail: "Yorgun, Kaygılı", style: .outline)
        }
    }
}

#Preview("Gece") { MoodPillSamples().one2Preview(.gece) }
#Preview("Gün") { MoodPillSamples().one2Preview(.gun) }
#Preview("AX3") { MoodPillSamples().one2Preview(.ax3) }
#endif
