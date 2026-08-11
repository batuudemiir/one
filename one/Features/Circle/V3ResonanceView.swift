//
//  V3ResonanceView.swift
//  one
//
//  Uyum — v3 prototip ekran 22 ("Frekans · uyum", ürün adı: Çevre · Uyum).
//
//  Üç bölüm:
//   1) Kendi renginde hero — "Bugün senin rengin" + duygu adı 36pt +
//      "N kişi bugün seninle aynı renkte".
//   2) Aynı renkteki kişiler listesi (40pt avatar + ad + saat).
//   3) Çevrendeki renk dağılımı — renk adı + oransal bar + sayı.
//
//  Sayaç/seri yok; ekran yalnız bugünün kesitini gösterir.
//

import SwiftUI
import CloudKit

struct V3ResonanceView: View {
    @Environment(\.dismiss) private var dismiss

    let friends: [CloudKitManager.FriendCircleData]
    let myMoments: [Moment]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    if !matches.isEmpty {
                        sectionLabel(NSLocalizedString("circle.sameColorLabel", comment: ""))
                            .padding(.top, 26)
                        matchList.padding(.top, 12)
                    }
                    if !distribution.isEmpty {
                        sectionLabel(NSLocalizedString("circle.distributionLabel", comment: ""))
                            .padding(.top, 26)
                        distributionList.padding(.top, 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(V3Tokens.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("general.close", comment: "")) { dismiss() }
                        .font(V3Typography.sans(15, weight: .semibold))
                        .foregroundColor(V3Tokens.ink)
                }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("circle.yourColorToday", comment: ""))
                .font(V3Typography.mono(11))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundColor((myMood?.ink ?? V3Tokens.mutedText).opacity(0.75))

            Text(myMood?.label ?? NSLocalizedString("circle.noColorToday", comment: ""))
                .font(ONEBrand.display(36))
                .tracking(-1)
                .foregroundColor(myMood?.ink ?? V3Tokens.ink)

            Text(matchLine)
                .font(V3Typography.sans(15))
                .foregroundColor((myMood?.ink ?? V3Tokens.mutedText).opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(myMood?.color ?? V3Tokens.wash)
        )
        .padding(.top, 16)
    }

    private var matchLine: String {
        guard myMood != nil else { return NSLocalizedString("circle.noColorTodayBody", comment: "") }
        return String(format: NSLocalizedString("circle.sameColorCount", comment: ""), matches.count)
    }

    // MARK: - Same-color list

    private var matchList: some View {
        VStack(spacing: 0) {
            ForEach(Array(matches.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 13) {
                    Text(String(item.name.prefix(1)).uppercased())
                        .font(ONEBrand.display(16))
                        .foregroundColor(item.mood.ink)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(item.mood.color))

                    Text(item.name)
                        .font(V3Typography.sans(16))
                        .foregroundColor(V3Tokens.ink)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(item.time)
                        .font(V3Typography.mono(11))
                        .tracking(1)
                        .foregroundColor(V3Tokens.ghostText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if index != matches.count - 1 {
                    Rectangle().fill(V3Tokens.hairline).frame(height: 1).padding(.leading, 16)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(V3Tokens.hairline, lineWidth: 1)
                )
        )
    }

    // MARK: - Distribution

    private var distributionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(distribution.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 12) {
                    Text(row.mood.label)
                        .font(V3Typography.sans(14))
                        .foregroundColor(V3Tokens.ink)
                        .frame(width: 76, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(V3Tokens.wash)
                            Capsule()
                                .fill(row.mood.color)
                                .frame(width: max(6, geo.size.width * ratio(row.count)))
                        }
                    }
                    .frame(height: 10)

                    Text("\(row.count)")
                        .font(V3Typography.mono(11))
                        .foregroundColor(V3Tokens.ghostText)
                        .frame(width: 22, alignment: .trailing)
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(V3Typography.mono(10))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundColor(V3Tokens.ghostText)
    }

    // MARK: - Derived

    /// Bugünün son anının rengi — widget ve kart ile aynı kaynak.
    private var myMood: V3Mood? {
        myMoments.last.flatMap { V3Mood.fromHex($0.moodColorHex) }
    }

    private struct Match {
        let name: String
        let mood: V3Mood
        let time: String
    }

    private var matches: [Match] {
        guard let mine = myMood else { return [] }
        return friends.compactMap { data -> Match? in
            guard let share = data.shares.first(where: {
                V3Mood.fromHex(($0["moodColor"] as? String) ?? "") == mine
            }) else { return nil }
            return Match(
                name: data.user["displayName"] as? String ?? "?",
                mood: mine,
                time: Self.hhmm(share["createdAt"] as? Date)
            )
        }
    }

    private var distribution: [(mood: V3Mood, count: Int)] {
        var counts: [V3Mood: Int] = [:]
        for data in friends {
            for share in data.shares {
                guard let mood = V3Mood.fromHex((share["moodColor"] as? String) ?? "") else { continue }
                counts[mood, default: 0] += 1
            }
        }
        return counts.map { (mood: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    private func ratio(_ n: Int) -> CGFloat {
        let top = distribution.first?.count ?? 1
        guard top > 0 else { return 0 }
        return CGFloat(n) / CGFloat(top)
    }

    private static func hhmm(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

#if DEBUG
#Preview("Uyum") {
    V3ResonanceView(
        friends: V3CircleSampleData.friends(),
        myMoments: V3CircleSampleData.myMoments()
    )
}
#endif
