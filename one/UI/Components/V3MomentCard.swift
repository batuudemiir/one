//
//  V3MomentCard.swift
//  one
//
//  Bir anın kartı — BeReal kompozisyonu.
//
//        HUZURLU                        21:14   ← başlık satırı: ne hissettin · ne zaman
//      ┌─────────────────────┐
//      │ ▣                   │   ▣ = mood rengi, "ikinci kamera" kutucuğu
//      │      FOTOĞRAF       │   fotoğraf 4:5, köşe yuvarlatılmış
//      │                     │   fotoğraf yoksa: mood rengi tuvali doldurur
//      └─────────────────────┘
//        Bugün nihayet sessizdi.        ← altyazı, ortalanmış, kağıt üstünde
//        CADILLAC — DEFTONES            ← mono şarkı satırı, soluk
//
//  **Neden BeReal.** Önceki kompozisyon fotoğrafın altına 88pt el yazısıyla
//  saati basıyordu: kartın en iri öğesi bir saatti ve o yüz (CaveatBrush)
//  uygulamanın başka hiçbir ekranında gövde metni olarak geçmiyor. Kart
//  kendi tipografik adasında yaşıyordu. Saat artık başlık satırında
//  `monoSM` — veri register'ı, uygulamanın geri kalanıyla aynı yüz.
//
//  **İki bakış, tek an.** BeReal'ın kartı aynı anın iki görüntüsünü yan yana
//  koyar (ön/arka kamera). Bizde eşdeğeri: gördüğün (fotoğraf) ve hissettiğin
//  (renk). Renk fotoğrafın sol üstünde kağıt çerçeveli bir kutucuk. Fotoğraf
//  yoksa renk zaten tuvalin kendisi — kutucuk o zaman çizilmiyor, aynı sinyal
//  iki kez görünmüyor.
//
//  **Yazı fotoğrafın üstünde değil.** Bir ara öyle denendi (scrim + tema
//  bağımsız `darkText`) ve iki bağımsız kontrast denetimi aynı sonuca vardı:
//  parlak bir fotoğrafın üstünde el yazısı 1.68:1, mono altyazı 3.1:1
//  çıkıyordu — ikisi de AA'nın çok altında. Yazı kağıda inince sorun kökten
//  bitiyor: `ink` ve `faintText` zaten ölçülmüş, `ContrastTests` ile
//  doğrulanmış tokenlar. Fotoğrafın üstünde duran tek şey renk kutucuğu —
//  metin taşımadığı için kontrast borcu da yok.
//
//  **Çerçeve yok.** Kart `surface` + hairline bir kutu değil; doğrudan
//  `paper` üzerinde duruyor, komşusundan boşlukla ayrılıyor.
//

import SwiftUI

struct V3MomentCard: View {
    let moment: Moment

    /// Fotoğrafa dokunulunca tam ekranı **parent** açıyor: viewer
    /// `GlobalUIState` üzerinden kabuk seviyesinde yaşıyor.
    var onTapPhoto: ((UIImage) -> Void)? = nil
    var onTapPhotoURL: ((URL) -> Void)? = nil

    /// URL yolundaki hero morph için. `nil` ise morph yok, kart yine çalışır.
    var photoNamespace: Namespace.ID? = nil
    /// Viewer şu an bu fotoğrafı gösteriyor mu — kaynak kart o sırada saklanır.
    var isPhotoViewerActive: Bool = false

    // Geometri `V3Tokens`'a taşındı: aynı sayıları tam ekran geçişi, poster
    // şablonu ve story çıktısı da okuyacak. Burada yalnız kısayolları var.
    static var canvasAspect: CGFloat { V3Tokens.momentCanvasAspect }
    static var colorCanvasHeight: CGFloat { V3Tokens.momentColorCanvasHeight }
    static var canvasRadius: CGFloat { V3Tokens.momentCanvasRadius }

    private var mood: V3Mood? { V3Mood.fromHex(moment.moodColorHex) }
    private var moodColor: Color { mood?.color ?? Color(hex: moment.moodColorHex) }
    /// Ad için `closest` de kabul: v1/v2 legacy hex'leri tam eşleşmiyor ama
    /// başlık satırı boş kalmamalı. Renk yine kaydedilen hex'in kendisi.
    private var moodLabel: String {
        (mood ?? V3Mood.closest(toHex: moment.moodColorHex))?.label ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, V3Tokens.spacingMD)

            canvas

            if moment.hasNote, let note = moment.note {
                Text(note)
                    .bodyLG()
                    .foregroundColor(V3Tokens.ink)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, V3Tokens.spacingLG)
            }

            if !songText.isEmpty {
                songLine
                    .padding(.top, moment.hasNote ? V3Tokens.spacingSM : V3Tokens.spacingLG)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        // Fotoğrafı büyütme eylemi VoiceOver'a burada açılıyor. Görselin
        // kendisi `accessibilityHidden`, üstelik `.onTapGesture` hiçbir
        // erişilebilirlik eylemi üretmiyor — ikisi birleşince özellik ekran
        // okuyucuya tamamen kapalı kalıyordu.
        .accessibilityAction(named: Text(NSLocalizedString("moment.a11y.openPhoto", comment: ""))) { openPhoto() }
        .accessibilityRemoveTraits(hasVisualPhoto ? [] : .isButton)
    }

    // MARK: - Başlık satırı

    /// BeReal'ın kart başlığı: solda kim/ne, sağda ne zaman. Bizde "kim" yok
    /// (arşiv zaten senin), yerine mood adı geçiyor. Saat burada — kartta
    /// başka hiçbir yerde tekrar etmiyor.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: V3Tokens.spacingSM) {
            if !moodLabel.isEmpty {
                Text(moodLabel)
                    .bodySMSemibold()
                    .foregroundColor(V3Tokens.ink)
                    .lineLimit(2)
            }

            Spacer(minLength: V3Tokens.spacingSM)

            if moment.scope == .private {
                Text(NSLocalizedString("moment.archiveTag", comment: ""))
                    .monoLabel()
                    .foregroundColor(V3Tokens.ghostText)
                    .lineLimit(1)
            }

            Text(ONEFormatters.time.string(from: moment.time))
                .monoSM()
                .monospacedDigit()
                .foregroundColor(V3Tokens.faintText)
                .lineLimit(1)
                .layoutPriority(1)
        }
    }

    // MARK: - Tuval (fotoğraf ya da renk)

    /// Kutuyu şeffaf bir placeholder tanımlıyor, görsel `overlay` içinde
    /// dolduruyor: `scaledToFill` bir `aspectRatio` ile doğrudan
    /// zincirlendiğinde kutu görselin oranına kaçıyor, fotoğrafsız duruma
    /// göre kart boyu oynuyordu.
    @ViewBuilder
    private var canvas: some View {
        let shape = RoundedRectangle(
            cornerRadius: V3MomentCard.canvasRadius,
            style: .continuous
        )
        if hasVisualPhoto {
            Color.clear
                .aspectRatio(V3MomentCard.canvasAspect, contentMode: .fit)
                .overlay { canvasContent }
                .clipShape(shape)
                .overlay(alignment: .topLeading) { moodChip }
        } else {
            moodColor
                .frame(maxWidth: .infinity)
                .frame(height: V3MomentCard.colorCanvasHeight)
                .clipShape(shape)
        }
    }

    /// "İkinci kamera" — fotoğrafın üstünde mood rengi. Kağıt çerçeve onu her
    /// fotoğraftan ayırıyor; metin taşımadığı için kontrast sorunu yok.
    /// Dokunma geçirmiyor: altındaki fotoğraf tam ekrana açılmaya devam etsin.
    private var moodChip: some View {
        RoundedRectangle(cornerRadius: V3Tokens.momentChipRadius, style: .continuous)
            .fill(moodColor)
            .frame(
                width: V3Tokens.momentChipWidth,
                height: V3Tokens.momentChipWidth / V3Tokens.momentCanvasAspect
            )
            .overlay(
                RoundedRectangle(cornerRadius: V3Tokens.momentChipRadius, style: .continuous)
                    .strokeBorder(V3Tokens.paper, lineWidth: V3Tokens.momentChipBorder)
            )
            .elevation(.sheetFloat)
            .padding(V3Tokens.spacingMD)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var canvasContent: some View {
        if let data = moment.photoData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .contentShape(Rectangle())
                .accessibilityHidden(true)
                .onTapGesture {
                    ONEHaptics.moodSelected()
                    onTapPhoto?(ui)
                }
        } else if let ref = moment.photoRef, let url = URL(string: ref) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                V3Tokens.wash
            }
            .modifier(PhotoMorph(namespace: photoNamespace, isSource: !isPhotoViewerActive))
            .opacity(isPhotoViewerActive ? 0 : 1)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
            .onTapGesture {
                ONEHaptics.moodSelected()
                onTapPhotoURL?(url)
            }
        }
        // Fotoğrafsız dal `canvas` içinde — 4:5 kutu yerine 200pt bant.
    }

    // MARK: - Mono şarkı satırı

    /// BeReal altyazısının altındaki ince meta satırı. Mood adı buradan
    /// çıktı — başlık satırına taşındı, iki yerde durmuyor.
    private var songLine: some View {
        Text(songText)
            .monoLabel(tracking: 1.4)
            .textCase(.uppercase)
            .foregroundColor(V3Tokens.faintText)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var songText: String {
        guard moment.hasSong else { return "" }
        let name = moment.songName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let artist = moment.songArtist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty && !artist.isEmpty { return "\(name) — \(artist)" }
        return name.isEmpty ? artist : name
    }

    // MARK: - Fotoğraf açma

    private var hasVisualPhoto: Bool {
        if let data = moment.photoData, !data.isEmpty { return true }
        if let ref = moment.photoRef, URL(string: ref) != nil { return true }
        return false
    }

    private func openPhoto() {
        if let data = moment.photoData, let ui = UIImage(data: data) {
            onTapPhoto?(ui)
        } else if let ref = moment.photoRef, let url = URL(string: ref) {
            onTapPhotoURL?(url)
        }
    }

    // MARK: - Erişilebilirlik

    /// Kart tek bir öğe olarak okunuyor. Renk noktası tek başına anlam
    /// taşımıyor — mood adı başlık satırında yazıyla da var.
    private var accessibilityText: String {
        var parts = [ONEFormatters.time.string(from: moment.time)]
        if !moodLabel.isEmpty { parts.append(moodLabel) }
        if hasVisualPhoto {
            parts.append(NSLocalizedString("moment.a11y.hasPhoto", comment: ""))
        }
        if !songText.isEmpty {
            parts.append(String(format: NSLocalizedString("moment.a11y.song", comment: ""), songText))
        }
        if let note = moment.note, !note.isEmpty {
            parts.append(String(format: NSLocalizedString("moment.a11y.note", comment: ""), note))
        }
        if moment.scope == .private {
            parts.append(NSLocalizedString("moment.a11y.privateScope", comment: ""))
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Opsiyonel hero morph

/// `matchedGeometryEffect` bir `Namespace.ID` zorunlu kılıyor ama kart
/// namespace'siz de kullanılabilmeli (preview, Çevre, poster). Modifier
/// namespace yoksa hiçbir şey uygulamıyor.
private struct PhotoMorph: ViewModifier {
    let namespace: Namespace.ID?
    let isSource: Bool

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: "archivePhoto", in: namespace, isSource: isSource)
        } else {
            content
        }
    }
}

// MARK: - Previews

#Preview("BeReal kompozisyonu") {
    ScrollView {
        VStack(spacing: V3Tokens.spacingXL5) {
            V3MomentCard(moment: .previewWithNote)
            V3MomentCard(moment: .previewColorOnly)
        }
        .padding(.horizontal, V3Tokens.channel)
        .padding(.vertical, V3Tokens.spacingXL3)
    }
    .background(V3Tokens.paper)
}

private extension Moment {
    static var previewWithNote: Moment {
        Moment(
            id: UUID(),
            date: Date(),
            time: Date(),
            moodIndex: 6,
            moodColorHex: V3Mood.huzurlu.hex,
            note: "Bugün nihayet sessizdi.",
            photoRef: nil,
            photoData: nil,
            songName: "Cadillac",
            songArtist: "Deftones",
            scope: .friends,
            entryIndex: 0
        )
    }

    static var previewColorOnly: Moment {
        Moment(
            id: UUID(),
            date: Date(),
            time: Date(),
            moodIndex: 1,
            moodColorHex: V3Mood.coskulu.hex,
            note: nil,
            photoRef: nil,
            photoData: nil,
            songName: nil,
            songArtist: nil,
            scope: .private,
            entryIndex: 1
        )
    }
}
