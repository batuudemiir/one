//
//  V3TopBar.swift
//  one
//
//  Tüm ekranların ortak üst çubuğu.
//
//  Neden: her ekran kendi `topBar`'ını yazıyordu — V3DayDetailView,
//  EchoV3Sections, PublicProfileView ve diğerleri, hepsi farklı yükseklik,
//  farklı düğme, farklı zemin.
//
//  Yapı — tek satır, 44pt:
//
//      [geri/kapat]  Ekran adı  BAĞLAM              [eylemler]
//
//  **Marka işareti çubuktan kalktı.** Dört sekme kökünün solunda `ONEAppMark`
//  duruyordu ve dördünde de aynı şeyi söylüyordu: "bu ONE". Kullanıcı zaten
//  ONE'ın içinde; o 26pt'lik yuva ekranın *adını* söylemek için harcanmalı.
//  Logo açılışta ve App Store'da marka; sekme kökünde tekrar.
//
//  Bunun ikinci sonucu: başlık artık **her zaman** görünüyor. Eskiden sekme
//  köklerinde başlık yalnız kaydırınca beliriyordu (`.onScroll`), yani
//  durağan halde Arşiv'in adı hiçbir yerde yazmıyordu ve Çevre kendi adını
//  gövdede 38pt tekrar yazmak zorunda kalıyordu. Bir ekranın adı bir kaydırma
//  jestinin arkasında durmamalı — "neredeyim?" sorusunun cevabı koşulsuz.
//
//  Rol iki tane:
//  - `.root`      — sekme kökü. Sol yuva boş, ad marka yüzüyle (Archivo 20).
//  - `.subScreen` — alt ekran / modal. Solda geri ya da kapat, ad 17pt sans.
//
//  `context` mono mikro etiket; başlığın **yanında**, aynı taban çizgisinde
//  durur. Eskiden başlıkla çapraz sönümleniyordu ve `.always` modunda hiç
//  çizilmiyordu — yani `V3Sheet` ve `EchoView` okunmayan bir parametre
//  geçiyordu. Artık ikisi birlikte: ad ne olduğunu, bağlam hangisi olduğunu
//  söylüyor ("Arşiv · AĞUSTOS 2026").
//
//  Zemin `progress` ile 0→1 açılıyor: durağan halde çubuk tamamen şeffaf,
//  kaydırıldıkça cam + hairline beliriyor. Apple'ın "scroll edge effect"i;
//  içerik çubuğun altından geçerken görünür kalıyor.
//
//  Hizalama: satır kenar payı `barInset` (20pt). Dairesel düğmeler 44pt
//  dokunma hedefinin içinde 36pt çiziliyor, yani görünen kenarları 24pt'ye
//  oturuyor — ekranların `channel` içerik kanalıyla aynı hat. Sol yuva
//  boşken metin bloğu 4pt kaydırılarak aynı hatta getiriliyor.
//

import SwiftUI

// MARK: - Leading slot

/// Çubuğun sol yuvası. Üst seviye enum: `V3TopBar` generic olduğu için
/// iç içe tanımlansaydı her `Trailing` için ayrı bir tip olurdu.
enum V3TopBarLeading {
    /// Alt ekran — geri (chevron).
    case back(() -> Void)
    /// Modal / tam ekran — kapat (xmark).
    case close(() -> Void)
    /// Sol yuva boş — sekme kökleri ve kendi kapatma düğmesini sağda taşıyan
    /// tam ekran yüzeyler (kamera vizörü).
    case none
}

// MARK: - Rol

/// Çubuğun iki rolü. Tek fark başlığın yüzü ve puntosu, ama fark bilinçli:
/// kök bir **isim** taşıyor (marka yüzü, masthead), alt ekran bir **yol**
/// taşıyor (okunur sans, geri düğmesinin yanında).
enum V3TopBarStyle {
    /// Sekme kökü — An · Arşiv · Çevre · Profil.
    case root
    /// Alt ekran, sheet, tam ekran modal.
    case subScreen
}

// MARK: - Top bar

struct V3TopBar<Trailing: View>: View {
    private let leading: V3TopBarLeading
    /// Geri/kapat düğmesinin zemini. Ayrı parametre çünkü Swift enum
    /// case'lerinin associated value'suna varsayılan verilemiyor — `.media`
    /// olmadığında kamera vizörü ve foto üstü ekranlar çıkış düğmesini
    /// çubuğun dışına, sağ yuvaya kaçırmak zorunda kalıyordu.
    private let leadingGround: V3TopBarIconGround
    private let style: V3TopBarStyle
    private let title: String?
    private let context: String?
    private let progress: CGFloat
    private let trailing: Trailing

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameters:
    ///   - leading: sol yuva — geri, kapat ya da boş.
    ///   - style: `.root` (sekme kökü) ya da `.subScreen`.
    ///   - title: ekranın adı. Her zaman görünür.
    ///   - context: adın yanındaki mono mikro etiket (tarih, ay, gün).
    ///   - progress: 0 durağan (şeffaf zemin), 1 kaydırılmış (cam + hairline).
    ///   - trailing: sağ yuva — `V3TopBarIconButton` ya da serbest içerik.
    init(
        leading: V3TopBarLeading = .none,
        leadingGround: V3TopBarIconGround = .surface,
        style: V3TopBarStyle = .subScreen,
        title: String? = nil,
        context: String? = nil,
        progress: CGFloat = 0,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading
        self.leadingGround = leadingGround
        self.style = style
        self.title = title
        self.context = context
        self.progress = min(max(progress, 0), 1)
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: V3Tokens.spacingMD) {
            leadingSlot
            textBlock
            Spacer(minLength: V3Tokens.spacingSM)
            trailing
        }
        .padding(.horizontal, V3Tokens.barInset)
        // `height` değil `minHeight`: en büyük Dynamic Type kademesinde
        // Archivo 20pt 30pt'ye çıkıyor ve sabit kutu onu kırpıyordu.
        .frame(minHeight: V3Tokens.minTouchTarget)
        .padding(.bottom, 6)
        .background(barBackground)
    }

    // MARK: - Leading

    /// Sol yuvada dairesel bir düğme var mı? Metin bloğunun optik hizası
    /// buna bağlı: düğme varsa hat zaten `channel`'a oturuyor, yoksa 4pt
    /// telafi gerekiyor.
    private var hasLeadingButton: Bool {
        switch leading {
        case .back, .close: return true
        case .none:         return false
        }
    }

    @ViewBuilder
    private var leadingSlot: some View {
        switch leading {
        case .back(let action):
            V3TopBarIconButton(
                systemName: "chevron.left",
                label: NSLocalizedString("general.back", comment: ""),
                ground: leadingGround,
                action: action
            )
        case .close(let action):
            V3TopBarIconButton(
                systemName: "xmark",
                label: NSLocalizedString("general.close", comment: ""),
                ground: leadingGround,
                action: action
            )
        case .none:
            EmptyView()
        }
    }

    // MARK: - Text block

    /// Ad ve bağlam aynı taban çizgisinde yan yana. Daralınca önce bağlam
    /// kesiliyor — `layoutPriority` adı koruyor, çünkü kesilen bir ekran adı
    /// gezinmeyi bozar, kesilen bir tarih yalnız bilgi kaybettirir.
    @ViewBuilder
    private var textBlock: some View {
        if title != nil || context != nil {
            HStack(alignment: .firstTextBaseline, spacing: V3Tokens.spacingSM) {
                if let title {
                    titleText(title)
                        .foregroundColor(V3Tokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .layoutPriority(1)
                }
                if let context {
                    Text(context)
                        .monoLabel(weight: .regular, tracking: 1.4)
                        .textCase(.uppercase)
                        .foregroundColor(V3Tokens.faintText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.leading, hasLeadingButton ? 0 : V3Tokens.spacingXS)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private func titleText(_ text: String) -> some View {
        switch style {
        // Marka yüzü (Archivo 20). Ekran adları tek kelime — bu punto ve
        // genişlikte masthead gibi okunuyor, gövde metniyle karışmıyor.
        case .root:
            Text(text).displaySM()
        // 17pt sans — `displayXS`'in kendi belgesinde tarif ettiği rol:
        // "alt başlık, navigation title".
        case .subScreen:
            Text(text).displayXS()
        }
    }

    // MARK: - Background

    /// Durağan halde tamamen şeffaf: içerik çubuğun altından geçerken
    /// görünür. Kaydırıldıkça cam ve hairline açılıyor.
    ///
    /// Zemin düz `paper` değil **cam**: alt gezinme çubuğu zaten cam bir
    /// kapsül, üstte opak bir şerit durunca ikisi aynı uygulamanın parçası
    /// gibi okunmuyordu. Malzemenin üstündeki ince `paper` katmanı ONE'ın
    /// sıcak kağıt tonunu geri veriyor — çıplak `regularMaterial` açık temada
    /// soğuk gri bir şerit bırakıyor.
    ///
    /// Reduce Transparency → cam yok, düz `paper`.
    @ViewBuilder
    private var barBackground: some View {
        Group {
            if reduceTransparency {
                V3Tokens.paper
            } else {
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay(V3Tokens.paper.opacity(0.35))
            }
        }
        .opacity(Double(progress))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(V3Tokens.hairline)
                .frame(height: 0.5)
                .opacity(Double(progress))
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Trailing'siz kısayol

extension V3TopBar where Trailing == EmptyView {
    init(
        leading: V3TopBarLeading = .none,
        leadingGround: V3TopBarIconGround = .surface,
        style: V3TopBarStyle = .subScreen,
        title: String? = nil,
        context: String? = nil,
        progress: CGFloat = 0
    ) {
        self.init(
            leading: leading,
            leadingGround: leadingGround,
            style: style,
            title: title,
            context: context,
            progress: progress
        ) { EmptyView() }
    }
}

// MARK: - Dairesel ikon düğmesi

/// Çubuğun standart eylem düğmesi: 36pt daire, 44pt dokunma hedefi.
///
/// Daire `surface` ile dolu — çubuk şeffafken altından geçen içeriğin
/// üstünde ikon kaybolmasın diye. Kenar hairline.
/// Düğmenin altında ne var?
///
/// Kapatma/geri düğmesi iki farklı zeminde duruyor ve `surface` + `ink`
/// çifti ikincisinde görünmez oluyor — bu yüzden her ekran kendi düğmesini
/// çizmeye başlamıştı (yedi ayrı boyut, yedi ayrı zemin).
enum V3TopBarIconGround {
    /// Kağıt zemin — sekme kökleri, ayarlar, sheet başlıkları.
    case surface
    /// Fotoğraf / hero görsel üstü. Koyu scrim + açık glif; altındaki
    /// görüntü ne olursa olsun okunur kalır.
    case media
}

extension View {
    /// Üst çubuk ikon kabuğu — 36pt görünen daire, 44pt dokunma hedefi.
    ///
    /// `V3TopBarIconButton` bunun üstüne kuruluyor. Ayrı bir modifier olarak
    /// duruyor çünkü her tetikleyici bir `Button` değil: `Menu` kendi
    /// label'ını çiziyor ve onun da aynı kabuğu alması gerekiyor, yoksa
    /// yan yana duran kapat/daha düğmeleri ayrışıyor.
    func v3TopBarIconGround(_ ground: V3TopBarIconGround = .surface) -> some View {
        self
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(ground.glyph)
            .frame(width: 36, height: 36)
            .background {
                switch ground {
                case .surface:
                    Circle()
                        .fill(V3Tokens.surface)
                        .overlay(Circle().strokeBorder(V3Tokens.hairline, lineWidth: 1))
                case .media:
                    Circle()
                        .fill(.black.opacity(0.32))
                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                }
            }
    }
}

extension V3TopBarIconGround {
    var glyph: Color {
        switch self {
        case .surface: return V3Tokens.ink
        case .media:   return V3Tokens.darkText
        }
    }
}

struct V3TopBarIconButton: View {
    let systemName: String
    let label: String
    /// Rozet sayısı; 0 ise rozet çizilmiyor.
    ///
    /// Boolean bir nokta değil **sayı**, çünkü "yeni bir şey var" ile "on bir
    /// şey var" farklı kararlar doğuruyor. Çevre bunu kendi geniş sayaç
    /// çipleriyle çözmüştü; o çipler 44pt kapsüldü ve aynı çubukta duran
    /// 36pt dairelerle aynı ailede okunmuyordu.
    var count: Int = 0
    var ground: V3TopBarIconGround = .surface
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasBadge: Bool { count > 0 }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .v3TopBarIconGround(ground)
                .overlay(alignment: .topTrailing) { badge }
                // Dokunma hedefi 44pt; görünen daire 36pt kalıyor.
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.onePressable)
        .animation(reduceMotion ? nil : ONEAnimation.easingChip, value: hasBadge)
        // Rozet kor bir sayı — tek başına renkle konuşuyordu, VoiceOver'da
        // hiç izi yoktu. "Renk tek başına anlam taşıyamaz" kuralı: sayı
        // erişilebilirlik değeri olarak da veriliyor.
        .accessibilityLabel(label)
        .accessibilityValue(hasBadge ? "\(count)" : "")
    }

    /// Kor kapsül + kemik rakam. Halka `paper` ile çiziliyor: rozet ikonun
    /// dairesine yapışmasın, kendi nesnesi olduğu görünsün — iOS'un rozet
    /// dili. Rakam grafik bir işaret (3.4:1, AA'nın grafik eşiği 3:1);
    /// okunması gereken değer `accessibilityValue`'da da duruyor.
    @ViewBuilder
    private var badge: some View {
        if hasBadge {
            Text(count > 99 ? "99+" : "\(count)")
                .monoMicro(weight: .medium, tracking: 0.2)
                .monospacedDigit()
                .foregroundColor(ONEBrand.bone)
                .padding(.horizontal, 4)
                .frame(minWidth: 16, minHeight: 16)
                .background(Capsule(style: .continuous).fill(ONEBrand.kor))
                // `stroke` yolun üstünde ortalanır — yarısı dışarıda kalıp
                // halka görevi görüyor, `strokeBorder` gibi dolguyu yemiyor.
                .overlay(Capsule(style: .continuous).stroke(V3Tokens.paper, lineWidth: 3))
                .offset(x: 5, y: -3)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
        }
    }
}

// MARK: - Previews

#Preview("Kök — ad + bağlam + eylem") {
    VStack(spacing: 0) {
        V3TopBar(style: .root, title: "An", context: "23 Ağustos", progress: 0) {
            V3TopBarIconButton(systemName: "alarm", label: "Hatırlatma") {}
        }
        V3TopBar(style: .root, title: "Çevre", progress: 1) {
            HStack(spacing: V3Tokens.spacingXS) {
                V3TopBarIconButton(systemName: "person.badge.plus", label: "İstekler", count: 3) {}
                V3TopBarIconButton(systemName: "bell", label: "Bildirimler", count: 12) {}
            }
        }
        Spacer()
    }
    .background(V3Tokens.paper)
}

#Preview("Alt ekran — geri + bağlam") {
    VStack(spacing: 0) {
        V3TopBar(
            leading: .back {},
            title: "3 an",
            context: "18 Ağustos 2026",
            progress: 0
        ) {
            V3TopBarIconButton(systemName: "ellipsis", label: "Daha fazla") {}
        }
        Spacer()
    }
    .background(V3Tokens.paper)
}
