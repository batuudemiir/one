//
//  V3Sheet.swift
//  one
//
//  Modal yüzeylerin ortak kabuğu.
//
//  Neden: sheet'ler bugün üç ayrı dille açılıyor. Sürükleme çubuğu üç
//  yerde görünür, üç yerde gizli, kalanında sistem varsayılanı; köşe
//  yarıçapı tek bir dosyada ayarlanmış (28), geri kalanı sistemin 10pt'si;
//  zemin iki yerde `paper`, kalanında `systemBackground` — yani koyu temada
//  ONE'ın #0C0C10 kağıdı yerine sistemin saf siyahı. Kapatma düğmesi ise
//  dokuz ekranda sistem `toolbar`'ının metin düğmesi, geri kalan her yerde
//  36pt dairesel `xmark`.
//
//  Buradaki üç API o üç kararı tek yere topluyor:
//
//    .v3Sheet(...)      → sunum kabuğu (köşe, zemin, sürükleme çubuğu)
//    V3SheetScreen      → üst çubuk + kaydırılabilir gövde (SubScreen'in modal ikizi)
//    V3SheetStack       → sheet içinde push gereken akışlar
//
//  `SubScreen` ile ilişkisi: aynı gövde, farklı sol yuva. Alt ekran yığında
//  bir yere *gider* (chevron), modal yığının üstünü *kapatır* (xmark). İkisi
//  de `V3TopBar` üstüne kuruluyor, dolayısıyla yükseklik, kenar payı ve
//  kaydırma davranışı ortak.
//

import SwiftUI

// MARK: - Sunum kabuğu

extension View {

    /// Sheet sunum kabuğu — köşe, zemin ve sürükleme çubuğu tek karar.
    ///
    /// - Parameters:
    ///   - detents: yükseklik kademeleri. Varsayılan `.large`.
    ///   - dragIndicator: varsayılan **gizli**. Kabuk zaten 36pt'lik dairesel
    ///     bir kapat düğmesi taşıyor; ikinci bir kapatma göstergesi koymak
    ///     aynı eylemi iki kez duyurmak oluyor. `V3SheetScreen` kullanmayan
    ///     çıplak seçici sheet'lerinde `.visible` geç — orada çubuk tek
    ///     kapatma işareti.
    func v3Sheet(
        detents: Set<PresentationDetent> = [.large],
        dragIndicator: Visibility = .hidden
    ) -> some View {
        self
            .presentationDetents(detents)
            .presentationDragIndicator(dragIndicator)
            .presentationCornerRadius(V3Sheet.cornerRadius)
            .presentationBackground(V3Tokens.paper)
    }
}

enum V3Sheet {
    /// Modal köşe yarıçapı.
    ///
    /// Sistemin varsayılanı 10pt; ONE'ın kart ölçeğinde en büyük yarıçap
    /// `radiusHero` (32). Sheet ikisinin arasında duruyor: ekranı kaplayan
    /// bir yüzey karttan yumuşak, tuvalden (52) sert olmalı.
    static let cornerRadius: CGFloat = 28
}

// MARK: - Modal ekran kabuğu

/// Üst çubuk + kaydırılabilir gövde. `SubScreen`'in modal karşılığı.
///
/// Sol yuvada `xmark` var, `chevron.left` değil: kullanıcı bir yığında
/// geriye gitmiyor, üstteki katmanı kapatıyor. `V3TopBar` bu ayrımı
/// `V3TopBarLeading` üzerinden zaten taşıyor.
///
/// Başlık her zaman görünür — modalin gövdesinde büyük başlık yok,
/// çubuktaki tek ad ekranın adı.
struct V3SheetScreen<Content: View>: View {
    let title: String
    /// Başlığın üstünde duran mono mikro etiket. Kaydırınca başlığa yer
    /// bırakmak için sönmüyor — modalde başlık zaten hep görünür, bağlam
    /// varsa ikisi birlikte anlam taşıyor.
    var context: String? = nil
    /// Sağ üstteki metin eylemi (`Kaydet`, `Gönder`). Yoksa yuva boş kalır.
    var actionTitle: String? = nil
    var isActionEnabled: Bool = true
    var onAction: (() -> Void)? = nil
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    /// Ekrana özgü scroll uzayı — aynı anda birden fazla modal canlı
    /// olabiliyor, isim çakışırsa offset'ler karışır. `SubScreen` ile aynı
    /// gerekçe.
    @State private var spaceName = "one.scroll.sheet.\(UUID().uuidString)"
    @State private var progress: CGFloat = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            Color.clear.frame(height: 0)
                .scrollOffsetSensor(spaceName: spaceName)

            content()
                .oneScreenBody()
                .padding(.top, V3Tokens.spacingSM)
                // Modalde alt sekme çubuğu yok; `SubScreen`'in 116pt'lik
                // payı burada gereksiz. 32pt son satırın ekran kenarına
                // yapışmasını engelliyor.
                .padding(.bottom, V3Tokens.spacingXL3)
        }
        .oneScreenGround()
        .topBarProgress($progress, spaceName: spaceName)
        .safeAreaInset(edge: .top, spacing: 0) {
            V3TopBar(
                leading: .close(onClose),
                title: title,
                context: context,
                progress: progress
            ) {
                if let actionTitle, let onAction {
                    V3SheetAction(
                        title: actionTitle,
                        isEnabled: isActionEnabled,
                        action: onAction
                    )
                }
            }
        }
    }
}

// MARK: - Sağ üst metin eylemi

/// Çubuğun metin eylemi. `SubScreenNavBar`'ın aynısı — ayrı bir tip olarak
/// duruyor çünkü modalde `isEnabled` gerekiyor (form geçerli değilken
/// `Kaydet` sönük durmalı) ve `SubScreenNavBar` o parametreyi taşımıyor.
struct V3SheetAction: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .bodyXSSemibold()
                .foregroundColor(isEnabled ? V3Tokens.korText : V3Tokens.ghostText)
                .padding(.horizontal, V3Tokens.spacingXS)
                // Dokunma hedefi metnin kutusundan büyük: 13pt'lik bir
                // etiketin kendi yüksekliği 16pt civarı, HIG asgarisi 44.
                .frame(minHeight: V3Tokens.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .disabled(!isEnabled)
    }
}

// MARK: - Sheet içinde push

/// Kendi içinde detaya push eden modal akışlar için.
///
/// Sistemin `NavigationStack`'i yalnız **yığın** için kullanılıyor; başlık
/// çubuğu her seviyede `V3SheetScreen` / `SubScreen` tarafından çiziliyor.
/// `.toolbar(.hidden)` o yüzden zorunlu: iki çubuk üst üste binmesin.
struct V3SheetStack<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Previews

#Preview("Modal — başlık + eylem") {
    V3SheetScreen(
        title: "Rapor et",
        context: "ÇEVRE",
        actionTitle: "Gönder",
        onClose: {}
    ) {
        VStack(alignment: .leading, spacing: V3Tokens.spacingLG) {
            ForEach(0..<6, id: \.self) { i in
                Text("Satır \(i + 1)")
                    .bodyMD()
                    .foregroundColor(V3Tokens.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(V3Tokens.spacingLG)
                    .oneCardBackground()
            }
        }
    }
}

#Preview("Modal — yalnız başlık") {
    V3SheetScreen(title: "Dil", onClose: {}) {
        Text("İçerik")
            .bodyMD()
            .foregroundColor(V3Tokens.mutedText)
    }
}
