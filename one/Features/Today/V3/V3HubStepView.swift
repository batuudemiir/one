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
        String(format: NSLocalizedString("hub.momentCount", comment: ""), count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, V3Tokens.spacingSM)

            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Dikey zaman çizgisi (rail) — sol tarafta 2pt line.
                    // scaleEffect ile yukarıdan aşağı çizilir.
                    Rectangle()
                        .fill(V3Tokens.hairline)
                        .frame(width: 2)
                        .scaleEffect(y: appeared || reduceMotion ? 1 : 0, anchor: .top)
                        .animation(reduceMotion ? nil : ONEAnimation.easingSaved,
                                   value: appeared)
                        .offset(x: 19, y: 8)

                    VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
                        ForEach(Array(day.moments.enumerated()), id: \.element.id) { idx, moment in
                            momentRow(moment)
                                .opacity(appeared || reduceMotion ? 1 : 0)
                                .offset(y: appeared || reduceMotion ? 0 : 6)
                                .animation(
                                    reduceMotion ? nil :
                                        ONEAnimation.easing.delay(Double(idx) * 0.05),
                                    value: appeared
                                )
                        }
                    }
                    .padding(.leading, 0)
                }
                .padding(.top, V3Tokens.spacingXL)
            }
            .onAppear { appeared = true }

            Spacer(minLength: 22)

            // Ghost (outline) — mevcut anların üstünde "ekleme" niyeti nazik
            // görünsün, ink dolgu butonu ekranı ezmesin.
            Button(action: onAddNew) {
                Text(NSLocalizedString("hub.addMoment", comment: ""))
                    .displayXS()
                    .foregroundColor(V3Tokens.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule(style: .continuous)
                            .stroke(V3Tokens.ink, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.onePressable)
        }
        // Diğer üç kök gibi çubuk bağlam taşıyor. Eskiden yalnız `.mark`
        // vardı: dört sekmeden üçünde çubuk bir şey söylerken An'da boş
        // duruyordu — `V3TopBar`'ın kendi belgesi "durağan halde bile çubuk
        // bir şey söylüyor" derken.
        //
        // Tarih başlıktan buraya taşındı, kopyalanmadı: hub kaydırılmadığı
        // için (iç ScrollView başlığın altında) gövde başlığı hiç kaybolmuyor
        // ve ikisi aynı anda görünseydi aynı bilgi iki kez yazılmış olurdu.
        .safeAreaInset(edge: .top, spacing: 0) {
            V3TopBar(leading: .mark, context: V3DateFormatter.headerLabel())
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            DayFill(day: day, cornerRadius: V3Tokens.radiusInner)
                .frame(width: 46, height: 46)

            Text(countLabel)
                .font(V3Typography.display(22, weight: .semibold))
                .tracking(-0.5)
                .foregroundColor(V3Tokens.ink)
            Spacer()
        }
    }

    // MARK: - Moment row

    private func momentRow(_ moment: Moment) -> some View {
        HStack(alignment: .top, spacing: V3Tokens.spacingMD) {
            // Rail üstündeki 40x40 renk kutucuğu — dış boşluk 0, saatle hizalı.
            RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                .fill((V3Mood.fromHex(moment.moodColorHex)?.color ?? Color(hex: moment.moodColorHex)))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: V3Tokens.spacingXS) {
                HStack(spacing: V3Tokens.spacingSM) {
                    Text(timeString(moment.time))
                        .font(V3Typography.mono(11, weight: .regular))
                        .tracking(1.2)
                        .foregroundColor(V3Tokens.faintText)
                    if moment.scope == .private {
                        Text(NSLocalizedString("moment.archiveTag", comment: ""))
                            .font(V3Typography.mono(11, weight: .regular))
                            .tracking(1.2)
                            .foregroundColor(V3Tokens.ghostText)
                    }
                }

                if let note = moment.note, !note.isEmpty {
                    Text(note)
                        .bodyMD()
                        .foregroundColor(V3Tokens.ink)
                        .lineLimit(3)
                } else if moment.hasSong {
                    Text(String(format: NSLocalizedString("hub.songLine", comment: ""), moment.songName ?? "—"))
                        .bodyXS()
                        .foregroundColor(V3Tokens.mutedText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, V3Tokens.spacingXS)
        }
        // Buton gibi davranmayı `onEditMoment` bağlıysa yapıyoruz.
        //
        // Eskiden koşulsuzdu: satır hem `contentShape` + `onTapGesture` ile
        // dokunulabilir görünüyor, hem VoiceOver'a `.isButton` diyordu — ama
        // container `onEditMoment`'i boş bir closure olarak geçiyor
        // ("Phase 4/6'ta bağlanacak"). Dokunan hiçbir şey olmuyordu; VoiceOver
        // kullanıcısı için ise düpedüz kırıktı: "düğme" duyup çift dokunuyor,
        // hiçbir tepki alamıyordu. Bağlanmamış bir düğme, düğme olmayan bir
        // satırdan kötüdür. `onEditMoment` bağlandığı gün burası kendiliğinden
        // çalışmaya başlar.
        .accessibilityElement(children: .combine)
        .modifier(HubRowTapAffordance(moment: moment, action: onEditMoment))
    }

    private func timeString(_ date: Date) -> String {
        ONEFormatters.time.string(from: date)
    }
}

// MARK: - Row tap affordance

/// Satırı yalnızca gerçekten bir eylem varsa dokunulabilir yapar.
///
/// `onTapGesture` değil `Button`: eskisi satıra `.isButton` özelliğini
/// veriyordu ama butonun *davranışını* vermiyordu — basıldığında hiçbir şey
/// olmuyor, sonuç ancak parmak kalkınca görünüyordu. Dokunma geri bildirimi
/// basma anında gelmeli; gecikince doğrudanlık hissi bir anda kayboluyor.
/// `Button` ayrıca kaydırma başlayınca basılı durumu kendisi iptal ediyor,
/// `onTapGesture`'ın kendi başına yapamadığı şey.
private struct HubRowTapAffordance: ViewModifier {
    let moment: Moment
    let action: ((Moment) -> Void)?

    func body(content: Content) -> some View {
        if let action {
            Button { action(moment) } label: {
                content.contentShape(Rectangle())
            }
            .buttonStyle(.onePressable)
        } else {
            content
        }
    }
}
