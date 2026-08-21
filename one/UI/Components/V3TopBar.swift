//
//  V3TopBar.swift
//  one
//
//  Tüm ekranların ortak üst çubuğu.
//
//  Neden: her ekran kendi `topBar`'ını yazıyordu — V3DayDetailView,
//  EchoV3Sections, PublicProfileView ve diğerleri, hepsi
//  farklı yükseklik, farklı düğme, farklı zemin. Sekme köklerinde ise hiç
//  yoktu: üst güvenli alan boş bir şerit olarak duruyordu.
//
//  Yapı — tek satır, 44pt:
//
//      [işaret/geri]  BAĞLAM              [eylemler]
//                     Başlık  ← yalnız kaydırınca belirir
//
//  - Kökte solda `ONEAppMark` durur, alt ekranda dairesel geri/kapat düğmesi.
//  - `context` mono mikro etiket ve **her zaman** görünür. Boş üst şeridi
//    bitiren şey bu: durağan halde bile çubuk bir şey söylüyor.
//  - `title` yalnız içerik altına kayınca belirir. Büyük başlık gövdede kalır;
//    kaybolduğunda çubuğa taşınır. iOS'un large-title davranışı, ONE diliyle.
//  - Zemin `paper` + alt hairline; ikisi de `progress` ile 0→1 açılır. Durağan
//    halde çubuk şeffaftır — içerik altından geçerken görünür kalır.
//
//  Hizalama: satır kenar payı 20pt. Dairesel düğmeler 44pt dokunma
//  hedefinin içinde 36pt çiziliyor, yani görünen kenarları 24pt'ye oturuyor —
//  ekranların 24pt içerik kanalıyla aynı hat. İşaret de 4pt kaydırılarak
//  aynı hatta getiriliyor.
//

import SwiftUI

// MARK: - Leading slot

/// Çubuğun sol yuvası. Üst seviye enum: `V3TopBar` generic olduğu için
/// iç içe tanımlansaydı her `Trailing` için ayrı bir tip olurdu.
enum V3TopBarLeading {
    /// Sekme kökü — kor işaret.
    case mark
    /// Alt ekran — geri (chevron).
    case back(() -> Void)
    /// Modal / tam ekran — kapat (xmark).
    case close(() -> Void)
    /// Sol yuva boş (nadir; bağlam etiketi sola dayanır).
    case none
}

/// Başlık ne zaman görünür?
enum V3TopBarTitleMode {
    /// Sekme kökleri: büyük başlık gövdede duruyor, çubuktaki küçük başlık
    /// yalnız o gövdeden çıkınca beliriyor.
    case onScroll
    /// Alt ekranlar: gövdede büyük başlık yok, çubuktaki başlık ekranın tek
    /// adı — her zaman görünür.
    case always
}

// MARK: - Top bar

struct V3TopBar<Trailing: View>: View {
    private let leading: V3TopBarLeading
    private let context: String?
    private let title: String?
    private let titleMode: V3TopBarTitleMode
    private let progress: CGFloat
    private let trailing: Trailing

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - leading: sol yuva — işaret, geri ya da kapat.
    ///   - context: mono mikro etiket. Her zaman görünür.
    ///   - title: ekran başlığı; `titleMode` ne zaman görüneceğini söyler.
    ///   - titleMode: `.onScroll` (kök) ya da `.always` (alt ekran).
    ///   - progress: 0 durağan (şeffaf zemin), 1 kaydırılmış (paper + hairline).
    ///   - trailing: sağ yuva — `V3TopBarIconButton` ya da serbest içerik.
    init(
        leading: V3TopBarLeading = .mark,
        context: String? = nil,
        title: String? = nil,
        titleMode: V3TopBarTitleMode = .onScroll,
        progress: CGFloat = 0,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading
        self.context = context
        self.title = title
        self.titleMode = titleMode
        self.progress = min(max(progress, 0), 1)
        self.trailing = trailing()
    }

    /// Başlık ile bağlam etiketi arasındaki geçiş eşiği. `.onScroll`'da
    /// yarıda değişiyor: altında bağlam, üstünde başlık.
    private var showsTitle: Bool {
        guard title != nil else { return false }
        return titleMode == .always || progress >= 0.5
    }

    var body: some View {
        HStack(spacing: 10) {
            leadingSlot
            textBlock
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, V3Tokens.barInset)
        .frame(height: 44)
        .padding(.bottom, 6)
        .background(barBackground)
        .animation(reduceMotion ? nil : ONEAnimation.easingChip, value: showsTitle)
    }

    // MARK: - Leading

    @ViewBuilder
    private var leadingSlot: some View {
        switch leading {
        case .mark:
            // Dekoratif: her sekme kökünde VoiceOver'ın duyduğu ilk şey
            // olmasın. Uygulama adı zaten sistemden biliniyor.
            ONEAppMark(side: 26)
                .padding(.leading, V3Tokens.spacingXS)
                .accessibilityHidden(true)
        case .back(let action):
            V3TopBarIconButton(
                systemName: "chevron.left",
                label: NSLocalizedString("general.back", comment: ""),
                action: action
            )
        case .close(let action):
            V3TopBarIconButton(
                systemName: "xmark",
                label: NSLocalizedString("general.close", comment: ""),
                action: action
            )
        case .none:
            EmptyView()
        }
    }

    // MARK: - Text block

    /// Bağlam ve başlık aynı yerde çapraz sönümleniyor — çubuk yüksekliği
    /// sabit kalsın, satır zıplamasın diye `ZStack`.
    @ViewBuilder
    private var textBlock: some View {
        if context != nil || title != nil {
            ZStack(alignment: .leading) {
                if let context {
                    Text(context)
                        .font(V3Typography.mono(10, weight: .regular))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundColor(V3Tokens.faintText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .opacity(showsTitle ? 0 : 1)
                        // `.opacity(0)` view'ı erişilebilirlik ağacından
                        // ÇIKARMIYOR. Gate olmadan VoiceOver ekranda tek şey
                        // görünürken ikisini birden okuyordu.
                        .accessibilityHidden(showsTitle)
                }
                if let title {
                    Text(title)
                        .bodyMDSemibold()
                        .foregroundColor(V3Tokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .opacity(showsTitle ? 1 : 0)
                        .accessibilityHidden(!showsTitle)
                        .offset(y: (showsTitle || reduceMotion) ? 0 : 4)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Background

    /// Durağan halde tamamen şeffaf: içerik çubuğun altından geçerken
    /// görünür. Kaydırıldıkça `paper` ve hairline açılır — metin, altından
    /// akan içeriğin üstünde okunur kalsın.
    private var barBackground: some View {
        V3Tokens.paper
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
        leading: V3TopBarLeading = .mark,
        context: String? = nil,
        title: String? = nil,
        titleMode: V3TopBarTitleMode = .onScroll,
        progress: CGFloat = 0
    ) {
        self.init(
            leading: leading,
            context: context,
            title: title,
            titleMode: titleMode,
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
    var badge: Bool = false
    var ground: V3TopBarIconGround = .surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .v3TopBarIconGround(ground)
                .overlay(alignment: .topTrailing) {
                    if badge {
                        Circle()
                            .fill(ONEBrand.kor)
                            .frame(width: 7, height: 7)
                            .offset(x: 1, y: -1)
                    }
                }
                // Dokunma hedefi 44pt; görünen daire 36pt kalıyor.
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.onePressable)
        // Rozet 7pt kor daire — tek başına renkle konuşuyordu, VoiceOver'da
        // hiç izi yoktu. "Renk tek başına anlam taşıyamaz" kuralı.
        .accessibilityLabel(label)
        .accessibilityValue(badge ? NSLocalizedString("general.new", comment: "") : "")
    }
}

// MARK: - Previews

#Preview("Kök — işaret") {
    VStack(spacing: 0) {
        V3TopBar(leading: .mark, title: "Arşiv", progress: 0)
        V3TopBar(leading: .mark, title: "Arşiv", progress: 1)
        Spacer()
    }
    .background(V3Tokens.paper)
}

#Preview("Alt ekran — geri + bağlam") {
    VStack(spacing: 0) {
        V3TopBar(
            leading: .back {},
            context: "18 Ağustos 2026",
            title: "3 an",
            progress: 0
        ) {
            V3TopBarIconButton(systemName: "ellipsis", label: "Daha fazla") {}
        }
        Spacer()
    }
    .background(V3Tokens.paper)
}
