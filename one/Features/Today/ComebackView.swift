//
//  ComebackView.swift
//  one
//
//  Uzun aradan sonra dönen kullanıcı. Suçlama yok — devam var.
//

import SwiftUI

/// Geri dönüş ekranı.
///
/// Bu ekranın tek işi **suçu ortadan kaldırmak.** Uzun süre yokken dönen
/// kullanıcı "serini kaybettin" duyarsa ikinci kez gitmesi kolaylaşır;
/// prototipin cümlesi bu yüzden "bir şey kaçırmadın" ve "seri falan yok."
///
/// Retention verisi de bunu söylüyor: Solo D30 %0'a karşı Sosyal D30 %20.7.
/// Dönen kullanıcıyı tutan şey seri değil, arkadaşlarının orada olması —
/// o yüzden ekranın merkezinde "sen yokken çevren ne yaptı" duruyor.
struct ComebackView: View {
    let daysAway: Int
    /// Kullanıcı yokken renk bırakan arkadaşların mood renkleri.
    let friendColors: [Color]
    /// Telafi penceresi içindeki boş günler.
    let backfillableDays: [Date]

    let onBackfill: (Date) -> Void
    let onStartToday: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(NSLocalizedString("comeback.eyebrow", comment: ""))
                    .monoLabel(tracking: 1.3)
                    .foregroundColor(V3Tokens.faintText)

                Text(headline)
                    .displayLG()
                    .foregroundColor(V3Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 11)

                Text(NSLocalizedString("comeback.reassurance", comment: ""))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .padding(.top, 12)

                if !friendColors.isEmpty {
                    whileYouWereAway
                        .padding(.top, ONETokens.spacingXL)
                }

                if !backfillableDays.isEmpty {
                    Text(NSLocalizedString("comeback.fillIfYouWant", comment: ""))
                        .monoLabel(tracking: 1.3)
                        .foregroundColor(V3Tokens.faintText)
                        .padding(.top, ONETokens.spacingXL)
                        .padding(.bottom, ONETokens.spacingSM)

                    VStack(spacing: 7) {
                        ForEach(backfillableDays, id: \.self) { date in
                            backfillRow(date)
                        }
                    }
                }

                Rectangle()
                    .fill(V3Tokens.ink.opacity(0.09))
                    .frame(height: 1)
                    .padding(.vertical, ONETokens.spacingXL)

                Button(action: onStartToday) {
                    Text(NSLocalizedString("comeback.markToday", comment: ""))
                        .bodySMMedium()
                        .foregroundColor(ONEBrand.bone)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule(style: .continuous).fill(V3Tokens.ink))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ONETokens.spacingXL)
            .padding(.top, ONETokens.spacingXL4)
            .padding(.bottom, 116)
        }
        .background(ONEBrand.bone.ignoresSafeArea())
    }

    // MARK: Headline

    /// "9 gündür yoktun. bir şey kaçırmadın." — iki cümle, ikincisi affediyor.
    private var headline: String {
        String(format: NSLocalizedString("comeback.headline", comment: ""), daysAway)
    }

    // MARK: While you were away

    private var whileYouWereAway: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(NSLocalizedString("comeback.whileAway", comment: ""))
                .monoLabel(tracking: 1.3)
                .foregroundColor(V3Tokens.faintText)

            Text(String(
                format: NSLocalizedString("comeback.friendsShared", comment: ""),
                friendColors.count
            ))
            .bodySM()
            .foregroundColor(V3Tokens.ink)

            // Üst üste binen halkalar: kimliği değil, varlığı gösteriyor.
            HStack(spacing: -7) {
                ForEach(Array(friendColors.prefix(8).enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(ONEBrand.bone, lineWidth: 2))
                }
            }
            .padding(.top, 3)
            .accessibilityHidden(true)
        }
        .padding(ONETokens.spacingXL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                .fill(Color.white.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ONETokens.radiusSheet, style: .continuous)
                .stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1)
        )
    }

    // MARK: Backfill rows

    private func backfillRow(_ date: Date) -> some View {
        Button { onBackfill(date) } label: {
            HStack(spacing: ONETokens.spacingMD) {
                Text(dayNumber(date))
                    .monoLabel(tracking: 0.4)
                    .foregroundColor(V3Tokens.mutedText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(V3Tokens.surface))

                Text(relativeName(date))
                    .bodySM()
                    .foregroundColor(V3Tokens.ink)

                Spacer()

                Text(NSLocalizedString("comeback.add", comment: ""))
                    .bodySMMedium()
                    .foregroundColor(ONEBrand.kor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(V3Tokens.ink.opacity(0.09), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(relativeName(date)), \(NSLocalizedString("comeback.add", comment: ""))")
    }

    private func dayNumber(_ date: Date) -> String {
        "\(Calendar.current.component(.day, from: date))"
    }

    /// "dün" / "önceki gün" / tarih — yakın günlerde sayı yerine kelime.
    private func relativeName(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0

        switch days {
        case 1: return NSLocalizedString("comeback.yesterday", comment: "")
        case 2: return NSLocalizedString("comeback.dayBefore", comment: "")
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.setLocalizedDateFormatFromTemplate("d MMMM")
            return formatter.string(from: date)
        }
    }
}
