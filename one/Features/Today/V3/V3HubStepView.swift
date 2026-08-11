//
//  V3HubStepView.swift
//  one
//
//  Adım 0 alternatifi — o gün zaten an varsa açılır.
//  Üstte gün karesi + tarih, dikey zaman çizgisi (rail) üzerinde saatli
//  an satırları, altta "Yeni an ekle".
//

import SwiftUI

struct V3HubStepView: View {
    /// Gün — bugün veya geçmiş.
    let day: Day
    /// "Yeni an ekle" butonuna dokununca.
    let onAddNew: () -> Void
    /// Bir an düzenlenmek istendiğinde (opsiyonel, Phase 4/6'ta bağlanır).
    var onEditMoment: ((Moment) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Timeline stagger anahtarı — appearance sonrası true, satırlar sırayla
    /// iner; günün ritmi yukarıdan aşağı akıyormuş hissi verir.
    @State private var appeared: Bool = false

    private var count: Int { day.moments.count }
    private var countLabel: String {
        count == 1 ? "Bugün bir an var" : "Bugün \(count) an var"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 24)

            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Dikey zaman çizgisi (rail) — sol tarafta 2pt line.
                    // scaleEffect ile yukarıdan aşağı çizilir.
                    Rectangle()
                        .fill(V3Tokens.hairline)
                        .frame(width: 2)
                        .scaleEffect(y: appeared || reduceMotion ? 1 : 0, anchor: .top)
                        .animation(reduceMotion ? nil : V3Tokens.easingSaved,
                                   value: appeared)
                        .offset(x: 19, y: 8)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(day.moments.enumerated()), id: \.element.id) { idx, moment in
                            momentRow(moment)
                                .opacity(appeared || reduceMotion ? 1 : 0)
                                .offset(y: appeared || reduceMotion ? 0 : 6)
                                .animation(
                                    reduceMotion ? nil :
                                        V3Tokens.easing.delay(Double(idx) * 0.05),
                                    value: appeared
                                )
                        }
                    }
                    .padding(.leading, 0)
                }
                .padding(.top, 22)
            }
            .onAppear { appeared = true }

            Spacer(minLength: 22)

            // Ghost (outline) — mevcut anların üstünde "ekleme" niyeti nazik
            // görünsün, ink dolgu butonu ekranı ezmesin.
            Button(action: onAddNew) {
                Text("Yeni an ekle")
                    .font(V3Typography.sans(17, weight: .semibold))
                    .foregroundColor(V3Tokens.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule(style: .continuous)
                            .stroke(V3Tokens.ink, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            DayFill(day: day, cornerRadius: 12)
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(V3DateFormatter.headerLabel())
                    .font(V3Typography.mono(11, weight: .regular))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundColor(V3Tokens.faintText)
                Text(countLabel)
                    .font(V3Typography.display(22, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundColor(V3Tokens.ink)
            }
            Spacer()
        }
    }

    // MARK: - Moment row

    private func momentRow(_ moment: Moment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Rail üstündeki 40x40 renk kutucuğu — dış boşluk 0, saatle hizalı.
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill((V3Mood.fromHex(moment.moodColorHex)?.color ?? Color(hex: moment.moodColorHex)))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(timeString(moment.time))
                        .font(V3Typography.mono(11, weight: .regular))
                        .tracking(1.2)
                        .foregroundColor(V3Tokens.faintText)
                    if moment.scope == .private {
                        Text("· ARŞİV")
                            .font(V3Typography.mono(11, weight: .regular))
                            .tracking(1.2)
                            .foregroundColor(V3Tokens.ghostText)
                    }
                }

                if let note = moment.note, !note.isEmpty {
                    Text(note)
                        .font(V3Typography.sans(15))
                        .foregroundColor(V3Tokens.ink)
                        .lineLimit(3)
                } else if moment.hasSong {
                    Text("Şarkı: \(moment.songName ?? "—")")
                        .font(V3Typography.sans(13))
                        .foregroundColor(V3Tokens.mutedText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEditMoment?(moment) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onEditMoment?(moment) }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
