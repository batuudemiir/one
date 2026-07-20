//
//  DayDetailView.swift
//  one
//
//  Prototip 18 — gün detayı. Mozaikteki bir kareye dokununca açılır.
//

import SwiftUI

/// Bir günün tam kaydı.
///
/// Prototipte hero mood renginde dolu bir blok: o günün rengi ekranın
/// üstünü kaplıyor. Kart değil zemin olması önemli — arşivde gün bir
/// "kayıt" değil, yaşanmış bir renk.
struct DayDetailView: View {
    let entry: DailyEntry
    let onBack: () -> Void
    var onEdit: (() -> Void)? = nil
    /// O gün arkadaşların bıraktığı renkler (varsa).
    var circleColors: [Color] = []

    var body: some View {
        SubScreen(
            title: shortDate,
            actionTitle: onEdit != nil ? NSLocalizedString("day.edit", comment: "") : nil,
            onBack: onBack,
            onAction: onEdit
        ) {
            VStack(alignment: .leading, spacing: 0) {
                hero
                songCard.padding(.top, ONETokens.spacingMD)

                if let note = entry.note, !note.isEmpty {
                    sectionLabel(NSLocalizedString("day.note", comment: ""))
                    InsightCard {
                        Text(note)
                            .bodySM()
                            .foregroundColor(ONETokens.oneInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let photoURL = entry.photoURL {
                    sectionLabel(NSLocalizedString("day.photo", comment: ""))
                    photo(photoURL)
                }

                if !circleColors.isEmpty {
                    Rectangle()
                        .fill(ONETokens.oneInk.opacity(0.09))
                        .frame(height: 1)
                        .padding(.vertical, ONETokens.spacingXL)

                    Text(NSLocalizedString("day.circleThatDay", comment: ""))
                        .monoLabel(tracking: 1.3)
                        .foregroundColor(ONETokens.oneStone)
                        .padding(.bottom, ONETokens.spacingSM)

                    HStack(spacing: -7) {
                        ForEach(Array(circleColors.prefix(10).enumerated()), id: \.offset) { _, c in
                            Circle()
                                .fill(c)
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(ONETokens.oneCream, lineWidth: 2))
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(longDate)
                .monoLabel(tracking: 1.3)
                .foregroundColor(.white.opacity(0.75))

            Text(entry.moodLabel.lowercased())
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 8)

            if !entry.feelingLabel.isEmpty {
                Text(entry.feelingLabel)
                    .font(.system(size: 13.5))
                    .foregroundColor(.white.opacity(0.82))
                    .padding(.top, 7)
            }
        }
        .padding(ONETokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                .fill(entry.moodColor)
        )
    }

    // MARK: Şarkı

    private var songCard: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(entry.moodColor)
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.92))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.songName)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundColor(ONETokens.oneInk)
                    .lineLimit(1)
                Text("\(entry.artistName) · \(entry.genre)")
                    .font(.system(size: 12.5))
                    .foregroundColor(ONETokens.oneAsh)
                    .lineLimit(1)
            }

            Spacer()

            Text(entry.time)
                .monoLabel(tracking: 0.5)
                .foregroundColor(ONETokens.oneStone)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .oneCardBackground(radius: ONETokens.radiusFriend, opacity: 0.78)
    }

    // MARK: Fotoğraf

    private func photo(_ url: URL) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                .fill(ONETokens.oneInk.opacity(0.06))
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(ONETokens.oneStone)
                )
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fill)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous))
    }

    // MARK: Yardımcılar

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .monoLabel(tracking: 1.3)
            .foregroundColor(ONETokens.oneStone)
            .padding(.top, ONETokens.spacingXL)
            .padding(.bottom, ONETokens.spacingSM)
    }

    private var shortDate: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f.string(from: entry.date)
    }

    private var longDate: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("EEEE d MMMM yyyy")
        return f.string(from: entry.date).lowercased()
    }
}
