import SwiftUI

/// Adım 3 — Kaydedildi ekranı. Prototipe uyumlu:
///   1. Photo (290pt) veya no-photo doneBlock (190pt, mood color)
///   2. "N. AN · TARIH" micro (DM Mono)
///   3. "Kaydedildi." (Archivo 34pt)
///   4. Description (bugün için X an var / arşivde bugünün karesi doldu)
///   5. Scope done micro
///   6. Alt: "Story kart oluştur" (ink) + "Arşive git" / "Güne dön" (ghost row)
struct V3SavedStepView: View {
    let mood: V3Mood
    let note: String?
    let photo: UIImage?
    let streakDays: Int
    let last7Days: [V3Mood?]   // ← unused now, backward compat

    let onArchive: () -> Void
    let onRestart: () -> Void          // "Güne dön" (hub'a)
    let onEditReminder: () -> Void     // ← unused now, backward compat
    let onEmptyDayTap: (Int) -> Void   // ← unused now, backward compat

    var reminderTimeLabel: String

    var momentOrdinal: Int? = nil
    var momentDateLabel: String? = nil
    var scope: MomentScope = .private
    /// Toplam an sayısı — description'da "N an var" için.
    var totalMomentsToday: Int = 1
    /// Story kart oluşturma tetikleyicisi (Phase 7 wiring).
    var onCreateStoryCard: (() -> Void)? = nil

    var body: some View {
        // Sabit bir `VStack`'ti: 290pt fotoğraf hero'su + 34pt başlık +
        // sarılan açıklama küçük ekranda (SE) ya da büyük Dynamic Type'ta
        // viewport'u aşınca `footer` — "Arşive git" / "Güne dön" — sekme
        // çubuğunun altında kalıyordu. Akışın son adımında çıkışsız kalmak
        // en kötüsü. `V3ColorStepView` ile aynı desen: içerik kayar,
        // footer altta sabit.
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                scrollContent
            }
            .scrollBounceBehavior(.basedOnSize)

            footer
        }
    }

    private var scrollContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero

            Text(ordinalLabel)
                .font(V3Typography.mono(10, weight: .regular))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.faintText)
                // Kazanılan sayı: "3. AN" → count-up ile açılır, kayıtın
                // ekstra ordinal artışı hissedilir hale gelir.
                .contentTransition(.numericText())
                .animation(ONEAnimation.easingSaved, value: momentOrdinal ?? totalMomentsToday)
                .padding(.top, V3Tokens.spacingXL2)

            Text("Kaydedildi.")
                .font(V3Typography.display(34, weight: .heavy))
                .tracking(-0.9)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, 10)
                .padding(.bottom, 10)

            Text(descriptionText)
                .bodyLG()
                .foregroundColor(V3Tokens.mutedText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(scopeText)
                .font(V3Typography.mono(11, weight: .regular))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.faintText)
                .padding(.top, V3Tokens.spacingSM)
                // Kaydırılan içeriğin sonu ile sabit footer arasında nefes payı.
                .padding(.bottom, V3Tokens.spacingXL)
        }
    }

    // MARK: - Hero (photo 290pt or doneBlock 190pt)

    @ViewBuilder
    private var hero: some View {
        if let photo {
            ZStack(alignment: .bottomLeading) {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                // Scrim — bottom 45% dark gradient (spec).
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 10/255, green: 10/255, blue: 14/255, opacity: 0),    location: 0.55),
                        .init(color: Color(red: 10/255, green: 10/255, blue: 14/255, opacity: 0.62), location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .allowsHitTesting(false)

                // Photo caption — mood name in bone (spec: Archivo 40pt).
                Text(mood.label)
                    .font(V3Typography.display(40, weight: .heavy))
                    .tracking(-1.1)
                    .foregroundColor(V3Tokens.paper)
                    .padding(.leading, V3Tokens.spacingXL2)
                    .padding(.bottom, V3Tokens.spacingXL2)

                // 7pt mood bar at bottom.
                VStack {
                    Spacer()
                    Rectangle().fill(mood.color).frame(height: 7)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 290)
            .clipShape(RoundedRectangle(cornerRadius: V3Tokens.radiusHero, style: .continuous))
            .padding(.top, 30)
        } else {
            // doneBlock — 190pt mood-color card, mood name in mood.ink at bottom-left.
            VStack(alignment: .leading) {
                Spacer()
                Text(mood.label)
                    .font(V3Typography.display(44, weight: .heavy))
                    .tracking(-1.2)
                    .foregroundColor(mood.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 190)
            .padding(V3Tokens.spacingXL2)
            .background(
                RoundedRectangle(cornerRadius: V3Tokens.radiusHero, style: .continuous)
                    .fill(mood.color)
            )
            .padding(.top, 34)
        }
    }

    // MARK: - Copy

    private var ordinalLabel: String {
        let ord = momentOrdinal ?? totalMomentsToday
        let dateStr = momentDateLabel ?? currentDateLabel()
        return "\(ord). AN · \(dateStr)"
    }

    private func currentDateLabel() -> String {
        let f = ONEFormatters.dayMonth
        return f.string(from: Date()).uppercased()
    }

    /// Description varyantları (spec):
    ///   - Çok an: "12 Temmuz için N an var. Kare renklere bölündü."
    ///   - Tek an bugün: "Arşivde bugünün karesi doldu."
    ///   - Tek an past-day: "12 Temmuz artık arşivde dolu."
    private var descriptionText: String {
        if totalMomentsToday > 1 {
            let day = momentDateLabel ?? currentDateLabel()
            return "\(day.capitalized) için \(totalMomentsToday) an var. Kare renklere bölündü."
        }
        return "Arşivde bugünün karesi doldu."
    }

    private var scopeText: String {
        scope == .private
            ? "Yalnızca senin arşivinde."
            : "Çevrendeki arkadaşlar görebilir."
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                onCreateStoryCard?()
            } label: {
                Text(NSLocalizedString("share.createStoryCard", comment: ""))
                    .displayXS()
                    .foregroundColor(V3Tokens.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Capsule().fill(V3Tokens.ink))
            }
            .buttonStyle(.onePressable)

            HStack(spacing: 10) {
                Button(action: onArchive) {
                    Text(NSLocalizedString("saved.goToArchive", comment: ""))
                        .displayXS()
                        .foregroundColor(V3Tokens.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().stroke(V3Tokens.ink, lineWidth: 1.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.onePressable)

                Button(action: onRestart) {
                    Text(NSLocalizedString("saved.backToDay", comment: ""))
                        .displayXS()
                        .foregroundColor(V3Tokens.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().stroke(V3Tokens.ink, lineWidth: 1.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.onePressable)
            }
        }
        .padding(.top, V3Tokens.spacingMD)
        // Kaydırılan içerik footer'ın altından geçiyor; üstteki yumuşak
        // geçiş kesik bir kenar yerine erime hissi veriyor (V3ColorStepView
        // ile aynı desen).
        .background(alignment: .top) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [V3Tokens.paper.opacity(0), V3Tokens.paper],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 18)
                V3Tokens.paper
            }
            .padding(.top, -18)
            .allowsHitTesting(false)
        }
    }
}
