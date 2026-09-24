import SwiftUI

/// Yükseklik ölçeği — gölgenin tek kaynağı.
///
/// **Kademeler koddan türetildi, tersi değil.** Bu tip zaten vardı ve doküman
/// satırı "Replaces ad-hoc .shadow(…) calls across the app" diyordu — ama
/// uygulamada **bir** yerde kullanılıyordu, 29 ham `.shadow(` çağrısı
/// duruyordu ve o 29 çağrı **27 farklı parametre setiyle** yazılmıştı.
/// Eski üç kademenin değerleri (0.04/r8/y2 · 0.08/r16/y6 · 0.10/r24/y10)
/// koddaki hiçbir gölgeye denk gelmiyordu; yani ölçek kimsenin kullanmadığı
/// bir şeyi tarif ediyordu ve kullanılmadığı için de kimse fark etmiyordu.
///
/// Şimdiki dört değerin **her biri** koddaki gerçek bir gölgeyle birebir aynı:
///
/// | kademe | değer | nereden geldi |
/// |---|---|---|
/// | `paperLift`  | 0.05 · r16 · y6  | `PublicProfilePinnedSongCard` |
/// | `cardRest`   | 0.06 · r20 · y8  | **üç dosyada birebir tekrarlanıyordu** |
/// | `sheetFloat` | 0.10 · r22 · y10 | `V3StoryComposer` kart gölgesi |
/// | `toastPop`   | 0.16 · r20 · y6  | `ONEToastView` |
///
/// `cardRest` bu işin gerçek beygiri: `FriendDetailView`, `SelfShareDetailView`
/// ve `FriendShareDetailView` aynı üçlüyü elle üç kez yazmıştı ve eski ölçekte
/// karşılığı yoktu. Bir ölçekte eksik kademe, ham sayı üretir.
///
/// ## Kapsam
///
/// Buradaki her şey **nötr** (siyah) ve **aşağı** düşen bir gölge — yani
/// "yüzey kağıttan ne kadar kalkmış" sorusunun cevabı. Kapsam dışı kalan üç
/// aile bilerek ham bırakıldı, çünkü işleri yükseklik bildirmek değil:
///
/// - **Foto üstü metin okunurluğu** (`PublicProfileHeroSection`,
///   `ProfileFormView`): gölge burada derinlik değil kontrast aracı.
/// - **Koyu zemin perdesi** (`ProfileView`, `FriendDetailView` hero): 0.4–0.5
///   opaklık, r40–60. Bunlar gölge değil, vinyet.
/// - **Mood parıltısı** (`SaveRitualMoment`, `DayPreviewCard`): renkli ve
///   bilerek öyle. Marka anı.
///
/// ## Bugünkü durum
///
/// 29 ham gölgeden 8'i bu ölçeğe bağlandı (yedisi birebir aynı değerde, biri
/// 4pt yarıçap farkıyla). Kalan 21'in 16'sı yukarıdaki kapsam dışı ailelerde
/// ya da özel durumlarda:
///
/// - `LiquidGlass` **iki katmanlı** bir gölge yazıyor (r12/y4 + r4/y2). Cam
///   malzemesinin derinliği için bilinçli katmanlama; tek kademeye inmez.
/// - `OneMascotView` gölgeyi `V3Tokens.ink` ile çiziyor, siyahla değil —
///   yani tema ile birlikte dönüyor. Ölçekteki nötr siyahtan **daha** doğru;
///   ölçeğe adaptif bir kademe eklenene kadar öyle kalsın.
/// - `BottomNavigation` ve `SubScreenChrome` gölgeyi koşullu seçiyor
///   (`colorScheme`, seçili durum).
///
/// Geriye kalan 5'i (0.12–0.25 arası, r8–r30) hiçbir kademeye yakın değil.
/// Onları zorlamak "ölçeğe oturtmak" olmaz, gerçek bir görsel değişiklik
/// olurdu — ayrı bir karar.
///
/// Yeni bir yüzey yazarken bu dördünden seç. Listede karşılığı yoksa önce
/// buraya kademe ekle — ham `.shadow(` yazma.
enum ONEElevation {
    /// Kağıdın üstünde duran hafif kart.
    case paperLift
    /// Detay kartı — ölçeğin en çok kullanılan kademesi.
    case cardRest
    /// Sheet, modal, story kartı: görünür şekilde yüzüyor.
    case sheetFloat
    /// Toast. Ölçeğin **sıralı** parçası değil: rastgele içeriğin üstünde
    /// okunması gerektiği için opaklığı yüksek ama yarıçapı dar tutuluyor —
    /// "daha yüksek" değil, "her zeminde ayırt edilir" demek.
    case toastPop

    var color: Color {
        switch self {
        case .paperLift:  return Color.black.opacity(0.05)
        case .cardRest:   return Color.black.opacity(0.06)
        case .sheetFloat: return Color.black.opacity(0.10)
        case .toastPop:   return Color.black.opacity(0.16)
        }
    }

    var radius: CGFloat {
        switch self {
        case .paperLift:  return 16
        case .cardRest:   return 20
        case .sheetFloat: return 22
        case .toastPop:   return 20
        }
    }

    var y: CGFloat {
        switch self {
        case .paperLift:  return 6
        case .cardRest:   return 8
        case .sheetFloat: return 10
        case .toastPop:   return 6
        }
    }
}

extension View {
    @ViewBuilder
    func elevation(_ level: ONEElevation) -> some View {
        self.shadow(color: level.color, radius: level.radius, x: 0, y: level.y)
    }
}
