//
//  V3MomentCard.swift
//  one
//
//  Bir anın kartı — referans kompozisyonun birebir karşılığı.
//
//      ┌─────────────────────┐
//      │                     │   fotoğraf — kare köşe, üstünde HİÇBİR ŞEY yok
//      │      FOTOĞRAF       │   yoksa: mood rengi, aynı kutu
//      │                     │
//      └─────────────────────┘
//                             ← boşluk, kompozisyonun yarısı bu
//                     21:14     el yazısı — iri, sağa dayalı, kağıt üstünde
//
//        ● HUZURLU · ŞARKI       mono altyazı — ortalanmış, soluk
//
//      Bugün nihayet sessizdi.   not — sola dayalı, tam okunur
//
//  **Yazı fotoğrafın üstünde değil.** Bir ara öyle denendi (scrim + tema
//  bağımsız `darkText`) ve iki bağımsız kontrast denetimi aynı sonuca vardı:
//  parlak bir fotoğrafın üstünde el yazısı 1.68:1, mono altyazı 3.1:1
//  çıkıyordu — ikisi de AA'nın çok altında. Dynamic Type'ın en büyük
//  kademesinde caption bloğu 127pt'ye çıkıp sabit 150pt'lik scrim'in dışına
//  taşıyordu. Yazı kağıda inince sorun kökten bitiyor: `ink` ve `faintText`
//  zaten ölçülmüş, `ContrastTests` ile doğrulanmış tokenlar.
//
//  Aynı hamle `V3Mood.ink` sorununu da kapatıyor — Ateşli (3.23:1),
//  Hüzünlü (4.24:1) ve Yorgun (4.22:1) 10pt mono için sınırın altındaydı.
//  Altyazı artık renk zeminde değil, o çiftlere hiç ihtiyaç yok.
//
//  **Çerçeve yok.** Kart `surface` + hairline bir kutu değil; doğrudan
//  `paper` üzerinde duruyor, komşusundan boşlukla ayrılıyor. Referansın
//  havasını veren şey bu — kutuya alındığı anda editoryal boşluk kayboluyor.
//
//  **Kare köşe.** Referansta fotoğrafın köşesi yuvarlatılmamış. `radiusTile`
//  yerine 0 — bilinçli, tek yerde tanımlı (`canvasRadius`).
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

    // Dikey ritim — referanstaki oranlardan türetildi (fotoğraf genişliğine
    // göre: boşluk 0.106 · el yazısı 0.32 · altyazı payı 0.076).
    private let gapToStamp: CGFloat = 22
    private let gapToMeta: CGFloat = 10
    private let gapToNote: CGFloat = 20

    private var mood: V3Mood? { V3Mood.fromHex(moment.moodColorHex) }
    private var moodColor: Color { mood?.color ?? Color(hex: moment.moodColorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            canvas

            // El yazısı damga — referansın en iri ikinci öğesi. Kağıt üstünde
            // `ink`, yani kontrast her fotoğrafta aynı ve garantili.
            V3HandText.time(moment.time, size: 88, color: V3Tokens.ink)
                .padding(.top, gapToStamp)

            metaLine
                .padding(.top, gapToMeta)

            if moment.hasNote, let note = moment.note {
                Text(note)
                    .bodyLG()
                    .foregroundColor(V3Tokens.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, gapToNote)
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
        } else {
            moodColor
                .frame(maxWidth: .infinity)
                .frame(height: V3MomentCard.colorCanvasHeight)
                .clipShape(shape)
        }
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

    // MARK: - Mono altyazı

    /// Referanstaki "Hand Mirror Snap · Aug 17, 2026" satırının karşılığı:
    /// ortalanmış, soluk, tracking'li mono. Saat burada tekrar edilmiyor —
    /// onu el yazısı söylüyor.
    ///
    /// Renk noktası referansta yok ama bizde olmak zorunda: uygulamanın tek
    /// sinyali renk ve fotoğraf varken rengin başka evi kalmıyor. Satırın
    /// kendi "·" ayraçlarıyla aynı ailede okunuyor.
    private var metaLine: some View {
        HStack(spacing: V3Tokens.spacingSM) {
            Circle()
                .fill(moodColor)
                .frame(width: 8, height: 8)

            Text(metaText)
                .font(V3Typography.mono(10, weight: .regular))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.faintText)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if moment.scope == .private {
                Text(NSLocalizedString("moment.archiveTag", comment: ""))
                    .font(V3Typography.mono(10, weight: .regular))
                    .tracking(1.4)
                    .foregroundColor(V3Tokens.ghostText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Mood adı + şarkı.
    private var metaText: String {
        var parts: [String] = []
        if let label = mood?.label { parts.append(label) }
        if moment.hasSong {
            let name = moment.songName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let artist = moment.songArtist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !name.isEmpty && !artist.isEmpty {
                parts.append("\(name) — \(artist)")
            } else if !name.isEmpty {
                parts.append(name)
            } else if !artist.isEmpty {
                parts.append(artist)
            }
        }
        return parts.joined(separator: " · ")
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
    /// taşımıyor — mood adı `metaText` içinde yazıyla da var.
    private var accessibilityText: String {
        var parts = [ONEFormatters.time.string(from: moment.time)]
        if let label = mood?.label { parts.append(label) }
        if hasVisualPhoto { parts.append("Fotoğraflı") }
        if moment.hasSong, !metaText.isEmpty { parts.append("Şarkı: \(metaText)") }
        if let note = moment.note, !note.isEmpty { parts.append("Not: \(note)") }
        if moment.scope == .private { parts.append("Arşivde, çevrede görünmüyor") }
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

#Preview("Referans kompozisyonu") {
    ScrollView {
        VStack(spacing: 56) {
            V3MomentCard(moment: .previewWithNote)
            V3MomentCard(moment: .previewColorOnly)
        }
        .padding(.horizontal, V3Tokens.spacingXL2)
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
