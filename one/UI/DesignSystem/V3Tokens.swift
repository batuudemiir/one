import SwiftUI
import UIKit

enum V3Tokens {

    // MARK: - Brand & neutrals

    /// Handoff "Renk — yüzeyler (light / dark)" tablosu. Işık değerleri
    /// değişmedi; koyu değerler tablodan birebir geldi. Tek marka vurgusu
    /// (`kor`) iki temada da aynı.
    private static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }

    /// Dört değerli varyant: tema × **Increased Contrast**.
    ///
    /// Ayarlar › Erişilebilirlik › Ekran ve Metin Boyutu › Kontrastı Artır
    /// açıkken sistem `trait.accessibilityContrast == .high` bildiriyor.
    /// ONE bunu hiç okumuyordu; kontrastı artıran kullanıcı hiçbir fark
    /// görmüyordu.
    ///
    /// Yükseltilmiş değerler AA (4.5:1) yerine AAA'ya (7:1) yaklaşıyor ama
    /// **hiyerarşiyi düzleştirmiyor**: üçünü birden 7:1'e çekmek muted /
    /// faint / ghost'u aynı renge indiriyordu. Her kademe kendi hedefine
    /// çıkıyor, sıra korunuyor. Oranlar `ContrastTests`'te doğrulanıyor.
    private static func adaptive(
        light: String, dark: String,
        lightHigh: String, darkHigh: String
    ) -> Color {
        Color(UIColor { trait in
            let high = trait.accessibilityContrast == .high
            let isDark = trait.userInterfaceStyle == .dark
            let hex: String
            switch (isDark, high) {
            case (false, false): hex = light
            case (false, true):  hex = lightHigh
            case (true,  false): hex = dark
            case (true,  true):  hex = darkHigh
            }
            return UIColor(Color(hex: hex))
        })
    }

    static let kor        = Color(hex: "#FF3B1F")   // brand / accent — tema-bağımsız
    static let ink        = adaptive(light: "#14141A", dark: "#F2F1EE")   // birincil metin
    static let paper      = adaptive(light: "#FBFAF7", dark: "#0C0C10")   // ekran zemini
    static let surface    = adaptive(light: "#FFFFFF", dark: "#16161C")   // kart, alan
    static let wash       = adaptive(light: "#EFEDE7", dark: "#1D1D24")   // foto yeri, iç raylar
    // Kenarlar normalde bilinçli olarak neredeyse görünmez (1.23:1) — v3'ün
    // kağıt estetiği bunun üzerine kurulu. Kontrastı artıran kullanıcı ise
    // kart sınırını *görmek* istiyor; açıkken gerçek bir çizgiye dönüyorlar.
    static let hairline   = adaptive(light: "#E6E3DB", dark: "#24242C",
                                     lightHigh: "#96969E", darkHigh: "#5E5E68")  // kenar (1.23 → 2.81)
    static let dashed     = adaptive(light: "#D6D2C7", dark: "#2E2E38",
                                     lightHigh: "#87878F", darkHigh: "#6B6B75")  // boş gün çerçevesi (→ 3.41)
    // Metin renkleri — üçü de WCAG AA (4.5:1) üstünde, hem `paper` hem
    // `surface` zemininde.
    //
    // Handoff'un özgün `faintText` (#8A8A96 → 3.27:1) ve `ghostText`
    // (#A8A59C → 2.36:1) değerleri açık temada AA'yı geçmiyordu; ikisi de
    // 10–11pt mono etiketlerde kullanılıyor (an sayısı, saat, kapsam) —
    // yani dekoratif değil, okunması gereken içerik. Koyu temada `ghostText`
    // (#6E6E7C → 3.89:1) aynı sorunu yaşıyordu.
    //
    // Koyu temada belirleyici zemin `paper` değil `surface`: #16161C,
    // #0C0C10'dan açık olduğu için kart içi metinde kontrast düşüyor —
    // kartların mono meta satırı tam da orada. Değerler en kötü zemine göre
    // seçildi.
    //
    // Üç kademe arasındaki kontrast farkı daraldığı için hiyerarşi artık
    // ağırlıklı olarak boyut/tracking/uppercase ile taşınıyor.
    // Oranlar `ContrastTests` içinde doğrulanıyor — değiştirirken testi çalıştır.
    // (Parantezdeki sayılar: açık tema / koyu tema, en kötü zeminde.)
    static let mutedText  = adaptive(light: "#6B6B78", dark: "#9A9AA6",
                                     lightHigh: "#494955", darkHigh: "#B6B6C4")  // ikincil gövde     (5.03 / 6.47 → 8.50 / 8.99)
    static let faintText  = adaptive(light: "#6E6E7A", dark: "#868694",
                                     lightHigh: "#52525E", darkHigh: "#A9A9B7")  // mikro etiket      (4.82 / 5.02 → 7.38 / 7.76)
    static let ghostText  = adaptive(light: "#72727E", dark: "#80808E",
                                     lightHigh: "#5B5B67", darkHigh: "#9D9DAB")  // yer tutucu, sayaç (4.55 / 4.63 → 6.41 / 6.73)

    /// Tema-bağımsız sabitler — koyu zeminli yüzeyler (poster, kamera vizörü,
    /// hikaye modu) açık temada da koyu kalmalı.
    static let darkGround = Color(hex: "#0C0C10")
    static let darkText   = Color(hex: "#F2F1EE")
    static let darkMuted  = Color(hex: "#9A9AA6")

    // MARK: - Dışa aktarılan yüzeyler (Export)

    /// Sabit tuvale çizilip **uygulamadan dışarı çıkan** yüzeylerin paleti:
    /// davet kartı, aylık poster, story kartı.
    ///
    /// Neden ayrı bir aile: bu yüzeyler `ImageRenderer` ile 1080×1920 gibi
    /// sabit bir piksel tuvaline çiziliyor ve Instagram'a, WhatsApp'a gidiyor.
    /// Oradaki `paper` / `ink` / `mutedText` **adaptive** — yani kullanıcı
    /// koyu temadaysa dışa aktarılan poster de koyu çıkıyor. Aynı ay, iki
    /// kullanıcı, iki farklı marka. Dışarıya çıkan ONE tek görünmeli.
    ///
    /// Değerler açık temanın kanonik değerleriyle **birebir aynı** —
    /// `V3Typography.monoFixed` ile aynı gerekçe: ekranda uyum sağla,
    /// tuvalde sabit kal.
    ///
    /// Ekranda okunan hiçbir yerde kullanma; adaptive tokenları kullan.
    enum Export {
        static let paper    = Color(hex: "#FBFAF7")
        static let surface  = Color(hex: "#FFFFFF")
        static let ink      = Color(hex: "#14141A")
        static let muted    = Color(hex: "#6B6B78")
        static let faint    = Color(hex: "#6E6E7A")
        static let hairline = Color(hex: "#E6E3DB")
        static let kor      = Color(hex: "#FF3B1F")

        /// Koyu zeminli export (foto arkalıklı story, poster koyu varyantı).
        static let ground   = Color(hex: "#0C0C10")
        static let onDark   = Color(hex: "#F2F1EE")
        static let onDarkMuted = Color(hex: "#9A9AA6")
    }

    // MARK: - Semantik renkler

    /// Durum renkleri. v3'ün tek marka vurgusu `kor`; bunlar marka değil,
    /// **durum** bildiriyor (başarı / bilgi / hata) ve o yüzden ayrı duruyorlar.
    ///
    /// `ONETokens`'tan birebir taşındılar. Orada `oneGreen` / `oneBlue` /
    /// `oneRed` adıyla duruyorlardı — isimleri rengi söylüyordu, işlevini
    /// değil, dolayısıyla "hata kırmızısı" ile "ateşli mood'u" aynı kelime
    /// uzayındaydı.
    static let success = Color(hex: "#4CAF82")
    static let info    = Color(hex: "#5B8DEF")
    static let danger  = Color(hex: "#E84040")
    static let warning = Color(hex: "#FB6F3B")

    // MARK: - Boşluk ölçeği

    /// 4pt ızgara. Bir boşluk seçerken menü bu.
    ///
    /// Ölçek `ONETokens`'tan taşındığında değerleri birebir korunmuştu
    /// (22 / 26 / 36 / 52 / 72) — o an doğru karardı, göç sırasında sessiz
    /// bir yerleşim değişikliği istemiyorduk. Ama sayım şunu gösterdi:
    /// ham boşlukların **%67'si ölçek dışındaydı**, ve en çok kullanılan
    /// büyük değerler 20 (81×) ile 24 (68×) idi — yani kod 4pt ızgarada
    /// çalışıyor, ölçek ise 22/26'da. Ölçek tarif etmesi gereken şeyi
    /// tarif etmiyordu; kimse ona bakmadığı için de kimse fark etmiyordu.
    ///
    /// Artık değerler koda uyduruldu. Eski → yeni:
    ///   22 → 20   (2pt)
    ///   26 → 24   (2pt)
    ///   36 → 32   (4pt)
    ///   52 → 48   (4pt — `spacingXL4` değil, `spacingXL5` oldu)
    ///   72 → kaldırıldı (hiç kullanılmıyordu)
    ///
    /// Ölçeğe **40 eklendi** (`spacingXL4`): 23 yerde kullanılıyordu ama
    /// karşılığı yoktu — tam da bu yüzden o 23 yer ham sayı yazmak
    /// zorundaydı. Bir ölçekte eksik basamak, ham sayı üretir.
    ///
    /// Göç tamamlandı: ölçekte karşılığı olan **hiçbir** ham sayı kalmadı
    /// (1137 ham → 578; token çağrısı 142 → 697). Kalan 578'in 107'si
    /// açık `.padding(0)`, 282'si aşağıdaki yarım adımlar, 189'u ise
    /// 2–15pt arası kıl payı düzeltmeler (ayırıcı kalınlığı, optik hizalama).
    ///
    /// **Kalan borç:** 6 / 10 / 14 / 18 hâlâ ham sayı olarak ~282 yerde
    /// geçiyor — sıkı iç boşluklar (ikon-metin arası, kapsül dolgusu).
    /// Izgaraya oturmuyorlar ve komşularına toplamak bu turda onaylanandan
    /// çok daha büyük bir görsel değişiklik olurdu. Yeni kod yazarken
    /// bunlara uzanma; ızgaradan seç.

    static let spacingXS:  CGFloat = 4
    static let spacingSM:  CGFloat = 8
    static let spacingMD:  CGFloat = 12
    static let spacingLG:  CGFloat = 16
    static let spacingXL:  CGFloat = 20
    static let spacingXL2: CGFloat = 24
    static let spacingXL3: CGFloat = 32
    static let spacingXL4: CGFloat = 40
    static let spacingXL5: CGFloat = 48

    // MARK: - Dokunma hedefi

    /// Apple HIG asgari dokunma hedefi. Token, çünkü 44 sayısı kodda
    /// tekrarlandığında "neden 44" bilgisi kayboluyor.
    static let minTouchTarget: CGFloat = 44

    // MARK: - Yerleşim

    /// İçerik kanalı — ekranın sol/sağ kenar payı.
    ///
    /// Tek sayı olarak duruyor çünkü hizalanması gereken şey bir "boşluk
    /// adımı" değil, **dikey bir hat**: kök sekmeler bu hattı kullanıyor
    /// (24), üst çubuk kendi 4pt düğme boşluğunu telafi ederek aynı hatta
    /// oturuyor, alt ekranların gövdesi ise `spacingXL`'den (22)
    /// besleniyordu — yani her alt ekranda başlık ile altındaki içerik 2pt
    /// kaymış duruyordu.
    static let channel: CGFloat = 24

    /// Üst çubuk satırının kenar payı.
    ///
    /// `channel` değil, `channel - 4`: çubuktaki dairesel düğmeler 44pt
    /// dokunma hedefi içinde 36pt çiziliyor, yani glifin görünen kenarı
    /// kendi kutusundan 4pt içeride. Bu pay o farkı geri veriyor —
    /// düğmenin *görünen* kenarı `channel` hattına oturuyor.
    static let barInset: CGFloat = channel - 4

    // MARK: - Radii
    //
    // Tam ölçek — küçükten büyüğe:
    //
    //     micro   2   iç şerit, ilerleme dolgusu, saç teli dörtgen
    //     swatch  6   küçük renk karesi, mini kapak
    //     chip    8   çip, etiket
    //     mosaic  9   arşiv ızgarası hücresi (kendi dünyası, bkz. aşağısı)
    //     inner  12   kart içi sıra, kapak görseli
    //     card   16   kart
    //     panel  20   panel, sheet gövdesi
    //     tile   24   büyük karo, vizör, alt sayfa
    //     hero   32   hero yüzey
    //     canvas 52   tam ekran tuval
    //     capsule    kapsül
    //
    // Bir yüzeye yarıçap verirken **ara değer uydurma** — en yakın kademeyi
    // seç. Ölçek bir zamanlar 22 ayrı sayıya dağılmıştı ve yan yana duran
    // kartların köşeleri gözle görülür biçimde farklıydı.

    /// Küçük swatch, mini karo, minik kapak — kartın *içindeki* en küçük
    /// dörtgenler. Ölçekte yoktu ve uygulama boşluğu 3/4/5/6 diye dört ayrı
    /// sayıyla dolduruyordu.
    static let radiusSwatch: CGFloat  = 6

    static let radiusChip: CGFloat    = 8

    /// İç öğe — kartın içine yerleşen sıra, kapak görseli, iç karo.
    /// `radiusChip` ile `radiusCard` arasındaki bu kademe ölçeğin en büyük
    /// boşluğuydu: 10/11/12/13 diye dört sayıyla, 20'den fazla yerde
    /// dolduruluyordu.
    static let radiusInner: CGFloat   = 12

    static let radiusCard: CGFloat    = 16
    static let radiusPanel: CGFloat   = 20
    static let radiusTile: CGFloat    = 24
    static let radiusHero: CGFloat    = 32
    static let radiusCanvas: CGFloat  = 52
    static let radiusCapsule: CGFloat = 999

    /// Mozaik hücresi ve içindeki mikro parçalar. Ölçeğin geri kalanından
    /// ayrı duruyor çünkü ızgara başka bir dünya: 7 sütunlu, 6pt boşluklu,
    /// hücre kenarı ~34–42pt. `radiusChip` (8) bile orada kalın kalıyor.
    /// `DayFill` yorumunda 9 · 5 · 4 · 2 diye tarif ediliyordu ama hiçbiri
    /// tokenlı değildi — ikinci bir gizli ölçek olmuştu.
    static let radiusMosaic: CGFloat = 9
    static let radiusMicro: CGFloat  = 2

    // MARK: - An kartı geometrisi
    //
    // Kart referans bir kompozisyonu birebir izliyor (fotoğraf → el yazısı
    // damga → mono altyazı) ve ölçüleri o referanstan türetildi. Bileşenin
    // içinde `static let` olarak duruyorlardı; buraya alındılar çünkü aynı
    // sayıları tam ekran geçişi, poster şablonu ve story çıktısı da okuyacak.

    /// Kartta fotoğrafın gösterim oranı. **Çekim oranı değil** — kamera 9:16
    /// çekiyor ki story'ye kırpmasız gitsin; kartta merkezden kırpılıyor.
    /// 9:16 gösterilseydi 345pt kanalda 613pt olurdu: ekranın neredeyse
    /// tamamı tek an, arşiv taranamaz hale gelirdi.
    static let momentCanvasAspect: CGFloat = 4.0 / 5.0

    /// Fotoğrafsız anın tuval yüksekliği — oran değil, sabit bant.
    /// Renk, fotoğrafla aynı 4:5 kutuya konduğunda 431pt'lik düz doygun bir
    /// blok oluyordu ve üstteki ~350pt sıfır bilgi taşıyordu.
    static let momentColorCanvasHeight: CGFloat = 200

    /// Kart tuvalinin köşesi. Referansta yuvarlatma yok — `radiusTile`'dan
    /// bilinçli sapma, tek yerde dursun ki tartışması da tek yerde olsun.
    static let momentCanvasRadius: CGFloat = 0

    // Hareket burada değil — `ONEAnimation`'da.
    //
    // Bir ara easing eğrileri burada, spring'ler `ONEAnimation`'da duruyordu:
    // iki namespace, tek konu. Üstelik buradaki yorum "v3'ün tek easing
    // eğrisi" diyordu ama `ONEAnimation`'ın spring'leri 87 çağrı noktasında
    // kullanılıyordu, yani iddia doğru değildi. Token dosyası artık yalnız
    // renk / boşluk / yarıçap / ölçü tanımlıyor.
}
