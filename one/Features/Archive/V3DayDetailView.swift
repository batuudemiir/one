//
//  V3DayDetailView.swift
//  one
//
//  v3 gün detayı — bir gündeki TÜM anları listeler.
//
//  Kompozisyon, yukarıdan aşağı:
//
//      [‹]                                  ← durağan: yalnız geri düğmesi
//      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓          ← günün renk imzası (morph hedefi)
//      17 Ağustos                            ← büyük başlık, Archivo 32
//      PAZAR · 3 AN                          ← mono meta
//
//      ┌ an kartları ┐
//
//  **Ekranın adı tarihtir ve artık gövdede duruyor.** Önce tarih de an
//  sayısı da üst çubuktaydı; gövdenin tek başlık öğesi 96pt'lik renk
//  şeridiydi. Yani ekranın en iri öğesi hiçbir şey *söylemeyen* soyut bir
//  banttı, kimliği ise çubuktaki 17pt'lik satırdı. Hiyerarşi ters duruyordu:
//  iOS'un büyük başlık kalıbında ad gövdede başlar, kaydırıldıkça çubuğa
//  **taşınır** — iki yerde birden asla durmaz.
//
//  Çubuk bu yüzden durağan halde adsız: `showsBarTitle` büyük başlık
//  çubuğun altına girdiği an açılıyor. Eşik sabit bir sayı değil, başlığın
//  ölçülen alt kenarı — Dynamic Type'ta başlık büyüyünce devir de o kadar
//  geç oluyor.
//
//  **Renk şeridi küçüldü (96 → 72).** Hâlâ ızgaradan gelen hero morph'un
//  hedefi ve hâlâ ilk sırada — dokunduğun kare büyüyerek buraya oturuyor,
//  sonra altında adı beliriyor (Apple'ın "aynı yoldan gir, aynı yoldan çık"
//  kuralı). Ama artık başlık değil, başlığın imzası.
//
//  Kural: "Bu güne an ekle" CTA yalnızca BUGÜN için gösterilir. Geçmiş
//  günlere retroaktif an eklenmez.
//

import SwiftUI

struct V3DayDetailView: View {
    let day: Day
    let onBack: () -> Void
    /// "Bu güne an ekle" — yalnızca bugün için anlamlı. Container geçse bile
    /// isToday=false ise CTA render edilmez.
    var onAddMoment: (() -> Void)? = nil

    /// Grid'den gelen hero morph namespace'i.
    @Environment(\.archiveDayNamespace) private var envDayNS
    @Namespace private var localDayNS
    private var dayNS: Namespace.ID { envDayNS ?? localDayNS }
    /// Foto viewer için ortak namespace (an fotoğrafı → tam ekran).
    @Environment(\.archivePhotoNamespace) private var envPhotoNS
    @Namespace private var localPhotoNS
    private var photoNS: Namespace.ID { envPhotoNS ?? localPhotoNS }
    @StateObject private var globalUI = GlobalUIState.shared

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Zemin opaklığı için: içeriğin scroll içindeki üst kenarı.
    @State private var scrollOffset: CGFloat = 0
    /// Çubuk başlığının devri için: büyük başlığın ölçülen alt kenarı.
    /// Başlangıçta "çok aşağıda" — ilk karede çubuk adsız açılsın.
    @State private var titleBottom: CGFloat = .greatestFiniteMagnitude

    private static let scrollSpace = "dayDetailScroll"

    // MARK: - İçerik

    private var count: Int { day.moments.count }
    private var countLabel: String {
        count == 1
            ? NSLocalizedString("archive.momentCount.one", comment: "")
            : String(format: NSLocalizedString("circle.momentCount", comment: ""), count)
    }
    /// Ekranın adı. Hem büyük başlık hem — devirden sonra — çubuk başlığı.
    private var dateTitle: String {
        ONEFormatters.dayMonth.string(from: day.date)
    }
    /// Başlığın altındaki mono satır: haftanın günü + an sayısı.
    ///
    /// Haftanın günü tarihten türetilebilir ama kimse kafadan hesaplamaz;
    /// "o gün pazardı" bir anıyı geri çağıran şeyin ta kendisi. Boş günde
    /// sayı yok — "0 an" bir bilgi değil, boşluğun tekrarı.
    private var metaLine: String {
        let weekday = ONEFormatters.weekday.string(from: day.date)
        return day.isEmpty ? weekday : "\(weekday) · \(countLabel)"
    }
    private var heroHexes: [String] {
        day.moments.map { $0.moodColorHex }
    }
    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }
    private var canAddMoment: Bool {
        isToday && onAddMoment != nil
    }
    /// Yüzen CTA yalnız **dolu** günde. Boş günde ekranın kendi CTA'sı var
    /// (`V3DayEmptyContent`) — ikisi birden çizilince aynı eylem için iki
    /// birebir aynı kapsül alt alta duruyordu.
    private var showsFloatingCTA: Bool {
        canAddMoment && !day.isEmpty
    }

    // MARK: - Ölçüler

    /// `V3TopBar`'ın kapladığı yükseklik: 44pt satır + 6pt alt pay.
    private static let barHeight: CGFloat = V3Tokens.minTouchTarget + 6
    /// Şeridin çubuğun altında başlaması için gereken pay.
    ///
    /// Durağan halde çubuk şeffaf; nefes payı olmazsa renk kompozisyonu
    /// geri düğmesinin hizasından başlıyor ve kırpılmış görünüyor.
    private static let barClearance: CGFloat = barHeight + V3Tokens.spacingLG
    /// Zeminin tamamen kapandığı kaydırma mesafesi. Kısa, çünkü şerit
    /// çubuğun altına girer girmez cam gelmeli — yoksa renk çubuğun
    /// arkasından değil *içinden* geçiyormuş gibi duruyor.
    private static let groundThreshold: CGFloat = 56

    /// 0 → şeffaf çubuk, 1 → cam + hairline.
    private var groundProgress: CGFloat {
        min(1, max(0, -scrollOffset) / Self.groundThreshold)
    }

    /// Büyük başlık çubuğun altına girdi mi?
    ///
    /// Sabit bir scroll eşiği yerine başlığın kendi alt kenarı ölçülüyor:
    /// Dynamic Type'ta başlık üç satıra çıkarsa devir de o kadar geç olmalı,
    /// yoksa çubuk adı gövdedeki ad hâlâ ekrandayken tekrar eder.
    private var showsBarTitle: Bool {
        titleBottom < Self.barHeight
    }

    var body: some View {
        ZStack(alignment: .top) {
            V3Tokens.paper.ignoresSafeArea()

            scrollContent

            stickyTopBar

            if showsFloatingCTA, let onAddMoment {
                floatingCTA(onAddMoment)
            }
        }
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: DayScrollOffsetKey.self,
                                value: geo.frame(in: .named(Self.scrollSpace)).minY
                            )
                        }
                    }

                header
                    .padding(.horizontal, V3Tokens.channel)
                    .padding(.top, Self.barClearance)

                content
                    .padding(.horizontal, V3Tokens.channel)
                    .padding(.top, day.isEmpty ? V3Tokens.spacingXL3 : V3Tokens.spacingXL2)
            }
            .padding(.bottom, showsFloatingCTA ? 110 : V3Tokens.spacingXL3)
        }
        .coordinateSpace(name: Self.scrollSpace)
        .onPreferenceChange(DayScrollOffsetKey.self) { scrollOffset = $0 }
        .onPreferenceChange(DayTitleBottomKey.self) { titleBottom = $0 }
    }

    // MARK: - Başlık bloğu

    /// Renk imzası → ad → meta. Sıra bilinçli: dokunduğun kare önce büyüyüp
    /// yerine oturuyor, adı ondan sonra beliriyor.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            DayFill(hexes: heroHexes, cornerRadius: V3Tokens.radiusPanel)
                .frame(height: 72)
                .matchedGeometryEffect(
                    id: V3ArchiveView.cellMorphID(for: day.date),
                    in: dayNS,
                    isSource: true
                )
                .accessibilityHidden(true)

            Text(dateTitle)
                .displayHero()
                .foregroundColor(V3Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, V3Tokens.spacingXL)
                // Çubuk devrinin ölçüm noktası. `background` içinde, çünkü
                // `overlay` metnin dokunma/erişilebilirlik ağacına giriyor.
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: DayTitleBottomKey.self,
                            value: geo.frame(in: .named(Self.scrollSpace)).maxY
                        )
                    }
                }

            Text(metaLine)
                .monoSM(weight: .regular)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.faintText)
                .padding(.top, V3Tokens.spacingSM)
        }
        // Ad ve meta VoiceOver'da tek başlık öğesi. Renk şeridi dışarıda:
        // taşıdığı bilgi (hangi mood'lar) an kartlarının her birinde yazıyla
        // zaten var, burada okunması aynı günü iki kez anlatmak olurdu.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Gövde

    @ViewBuilder
    private var content: some View {
        if day.isEmpty {
            V3DayEmptyContent(
                message: emptyMessage,
                onAddMoment: canAddMoment ? onAddMoment : nil
            )
        } else {
            momentList
        }
    }

    /// Kartlar arası 48pt. Ayrımı kenarlık değil boşluk yapıyor
    /// (bkz. `V3MomentCard` — çerçevesiz kart kararı).
    ///
    /// `scrollTransition`: kartlar ekranın uçlarına yaklaşırken hafifçe
    /// soluyor — cam çubuğun ve alttaki CTA degradesinin altına sert bir
    /// kenarla değil, sönerek giriyorlar. Reduce Motion'da ölçek düşüyor,
    /// opaklık kalıyor (hareket değil, derinlik ipucu).
    private var momentList: some View {
        let shrink: CGFloat = reduceMotion ? 0 : 0.02
        return LazyVStack(alignment: .leading, spacing: V3Tokens.spacingXL5) {
            ForEach(day.moments) { moment in
                V3MomentCard(
                    moment: moment,
                    onTapPhoto: { ui in
                        withAnimation(ONEAnimation.easing) {
                            globalUI.archiveMomentImage = ui
                        }
                    },
                    onTapPhotoURL: { url in
                        withAnimation(ONEAnimation.easing) {
                            globalUI.archivePhotoURL = url
                        }
                    },
                    photoNamespace: photoNS,
                    isPhotoViewerActive: globalUI.archivePhotoURL.map {
                        $0.absoluteString == moment.photoRef
                    } ?? false
                )
                .scrollTransition(axis: .vertical) { view, phase in
                    let edge = min(1, abs(phase.value))
                    return view
                        .opacity(1 - edge * 0.3)
                        .scaleEffect(1 - edge * shrink)
                }
            }
        }
    }

    /// Bugün → ne yapılacağını yazar. Geçmiş gün → retroaktif an eklenmediği
    /// için yapılacak bir şey yok; durum olduğu gibi söyleniyor.
    private var emptyMessage: String {
        NSLocalizedString(
            isToday ? "archive.dayEmpty.today" : "archive.dayEmpty.past",
            comment: ""
        )
    }

    // MARK: - Sticky top bar

    /// Ad ve bağlam yalnız büyük başlık ekrandan çıkınca beliriyor; durağan
    /// halde çubukta sadece geri düğmesi var.
    ///
    /// Geçiş `easingChip` ile yumuşatılıyor — `title`/`context` nil'den
    /// dizeye dönerken SwiftUI metin bloğunu opaklıkla getiriyor. Reduce
    /// Motion'da da açık: burada hareket eden bir şey yok, yalnız opaklık.
    private var stickyTopBar: some View {
        V3TopBar(
            leading: .back {
                ONEHaptics.nudge()
                onBack()
            },
            title: showsBarTitle ? dateTitle : nil,
            context: showsBarTitle && !day.isEmpty ? countLabel : nil,
            progress: groundProgress
        )
        .animation(ONEAnimation.easingChip, value: showsBarTitle)
    }

    // MARK: - Yüzen CTA

    /// Kartların üstünde duruyor. Altında `paper`'dan şeffafa bir geçiş var:
    /// düz bir kapsül kayan fotoğrafların üstünde kesik gibi duruyordu, şimdi
    /// içerik çubuğa girerken soluyor (Apple'ın scroll edge effect'i — sert
    /// bir ayraç yerine yumuşak bir maske).
    private func floatingCTA(_ action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Spacer()

            V3PrimaryButton(
                title: NSLocalizedString("archive.addMomentToDay", comment: ""),
                isFullWidth: true,
                action: action
            )
            .padding(.horizontal, V3Tokens.channel)
            .padding(.bottom, V3Tokens.spacingXL2)
        }
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [V3Tokens.paper.opacity(0), V3Tokens.paper],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 132)
            // Alt güvenli alana da uzanmalı: yoksa home indicator şeridinde
            // kartlar maskesiz kayıyor ve kapsülün altından çıkıyor.
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Boş gün

/// Boş günün gövdesi.
///
/// Eskiden burada 140pt'lik iç içe iki kesikli çerçeve, `displayLG` bir
/// başlık ve bir düğme vardı. Kesikli çerçeve artık gereksiz: `DayFill`
/// boş günde zaten kesikli çiziliyor, yani başlıkta bir kesikli dikdörtgen,
/// hemen altında bir kesikli dikdörtgen daha duruyordu. Başlık da ikinci bir
/// masthead'di — ekranın adı artık tarih, boşluk onun yerine geçemez.
///
/// Kalan: tek cümle + (yalnız bugünse) tek düğme.
private struct V3DayEmptyContent: View {
    let message: String
    let onAddMoment: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            Text(message)
                .bodyXL()
                .foregroundColor(V3Tokens.mutedText)
                .fixedSize(horizontal: false, vertical: true)

            if let onAddMoment {
                V3PrimaryButton(
                    title: NSLocalizedString("archive.addNow", comment: ""),
                    isFullWidth: true,
                    action: onAddMoment
                )
            }
        }
    }
}

// MARK: - Ölçüm probları

/// İçeriğin scroll içindeki üst kenarı — çubuk zemininin opaklığı.
private struct DayScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Büyük başlığın alt kenarı — çubuk başlığının devir noktası.
private struct DayTitleBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
