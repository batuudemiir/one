//
//  V3DayDetailView.swift
//  one
//
//  v3 gün detayı — bir gündeki TÜM anları listeler.
//
//  Header collapse davranışı: scroll ilerledikçe hero şerit + büyük başlık
//  yukarı kayar; üst kısımda 44pt kompakt sticky bar (mini stripe + tarih·N an)
//  fade in olur. Kapat butonu her zaman erişilebilir.
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

    @State private var scrollOffset: CGFloat = 0

    private var count: Int { day.moments.count }
    private var countLabel: String {
        count == 1
            ? NSLocalizedString("archive.momentCount.one", comment: "")
            : String(format: NSLocalizedString("circle.momentCount", comment: ""), count)
    }
    /// Çubuğun tek satırı: tarih + an sayısı. İkisi de başka hiçbir yerde
    /// tekrar etmiyor.
    private var barContext: String {
        day.isEmpty ? dateLabel : "\(dateLabel) · \(countLabel)"
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

    // MARK: - Collapse

    /// Başlığın gerçekten ekrandan çıktığı yer.
    ///
    /// 40pt idi ve bozuktu: çubuk 40pt'de tamamen doluyordu ama genişletilmiş
    /// başlık (hero + damga + sayaç) 276pt aşağıdaydı ve hâlâ görünürdü.
    /// ~230pt boyunca ekranda aynı bilginin üç kopyası duruyordu — çubukta
    /// tarih + "3 AN", gövdede "Aug 17" + "3 AN".
    ///
    /// Artık yalnız zemin opaklığını sürüyor — çubuğun İÇERİĞİ sabit, kaydırınca
    /// bir şey belirip kaybolmuyor. O yüzden eşik düşük: hero çubuğun altına
    /// girmeye başlar başlamaz zemin kapanmalı ki metin okunur kalsın.
    private static let collapseThreshold: CGFloat = 56

    /// `V3TopBar`'ın kapladığı yükseklik (44pt satır + 6pt alt pay) + nefes payı.
    ///
    /// 44'tü ve şeridin üst 6pt'si çubuğun altında kalıyordu: durağan halde
    /// çubuk şeffaf olduğu için renk kompozisyonu geri düğmesinin hizasından
    /// başlıyor, ekranın tek başlık öğesi kırpılmış görünüyordu.
    private static let barClearance: CGFloat = 50 + V3Tokens.spacingLG

    /// Yüzen CTA yalnız **dolu** günde. Boş günde ekranın kendi CTA'sı var
    /// (`emptyDayContent`) — ikisi birden çizilince aynı eylem için iki
    /// birebir aynı kapsül alt alta duruyordu.
    private var showsFloatingCTA: Bool {
        canAddMoment && !day.isEmpty
    }
    /// 0 → header genişletilmiş, 1 → tamamen kollapse.
    private var collapseProgress: CGFloat {
        let scrolled = max(0, -scrollOffset)
        return min(1, scrolled / Self.collapseThreshold)
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

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: DayDetailScrollOffsetKey.self,
                        value: geo.frame(in: .named("dayDetailScroll")).minY
                    )
            }
            .frame(height: 0)

            VStack(alignment: .leading, spacing: 0) {
                // Ekranın **tek** başlık öğesi: günün renk kompozisyonu.
                // Aynı zamanda ızgaradan gelen morph'un kaynağı.
                //
                // Yanında bir el yazısı damga ("Aug 17") ve bir mono sayaç
                // ("3 AN") daha vardı. Üçü birlikte çubuktakileri tekrar
                // ediyordu: tarih iki yerde (üstelik biri Türkçe biri
                // İngilizce), sayı iki yerde, renk kompozisyonu iki yerde.
                // Kaydırınca azalmıyor, artıyordu — çubuğa mini şerit ve
                // sayaç ekleniyordu. Tarih ve sayı artık yalnız çubukta,
                // renk yalnız burada.
                DayFill(hexes: heroHexes, cornerRadius: V3Tokens.radiusPanel)
                    .frame(height: 96)
                    .matchedGeometryEffect(
                        id: V3ArchiveView.cellMorphID(for: day.date),
                        in: dayNS,
                        isSource: true
                    )
                    .padding(.horizontal, V3Tokens.channel)
                    .padding(.top, Self.barClearance)

                if day.isEmpty {
                    emptyDayContent
                        .padding(.horizontal, V3Tokens.channel)
                        .padding(.top, V3Tokens.spacingXL4)
                } else {
                    // Kartlar arası 48pt. Ayrımı kenarlık değil boşluk
                    // yapıyor (bkz. V3MomentCard — çerçevesiz kart kararı).
                    // 56'ydı: altyazının bir sonraki fotoğrafa ait gibi
                    // okunmaması için gereken paydı. Kart artık kendi başlık
                    // satırıyla (mood + saat) başlıyor — üstü işaretli olduğu
                    // için o kadar paya ihtiyacı kalmadı; ölçek dışı 56 yerine
                    // `spacingXL5`.
                    VStack(alignment: .leading, spacing: V3Tokens.spacingXL5) {
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
                        }
                    }
                    .padding(.horizontal, V3Tokens.channel)
                    .padding(.top, V3Tokens.spacingXL2)
                }
            }
            .padding(.bottom, showsFloatingCTA ? 110 : V3Tokens.spacingXL3)
        }
        .coordinateSpace(name: "dayDetailScroll")
        .onPreferenceChange(DayDetailScrollOffsetKey.self) { offset in
            scrollOffset = offset
        }
    }

    // MARK: - Sticky top bar

    /// Ortak `V3TopBar`. Eskiden burası kendi çubuğunu çiziyordu ve durağan
    /// halde solu boştu — yalnız sağda bir "Kapat" vardı, üst şerit bomboş
    /// duruyordu. Artık sol yuvada geri düğmesi, yanında tarih **her zaman**
    /// duruyor; kollapse'de sağda mini şerit + an sayısı beliriyor.
    private var stickyTopBar: some View {
        V3TopBar(
            leading: .back {
                ONEHaptics.nudge()
                onBack()
            },
            context: barContext,
            progress: collapseProgress
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(barContext)
    }

    // MARK: - Empty day

    private var emptyDayContent: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            // Kesikli çerçeve `dashed` token'ıyla çiziliyor. `hairline`
            // kullanılıyordu — o token dolu ayraç hattı için ölçüldü,
            // kesikli çerçevede tırtıklar zeminde kayboluyordu.
            ZStack {
                RoundedRectangle(cornerRadius: V3Tokens.radiusPanel, style: .continuous)
                    .strokeBorder(V3Tokens.dashed, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                RoundedRectangle(cornerRadius: V3Tokens.radiusInner, style: .continuous)
                    .strokeBorder(V3Tokens.dashed, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(width: 60, height: 60)
            }
            .frame(height: 140)
            .accessibilityHidden(true)

            // Tek cümle. Önce üç kopya vardı ve üçü de aynı şeyi söylüyordu:
            // başlık "Bugün henüz bir an yok.", altyazı "İlk anını şimdi
            // bırak.", düğme "Şimdi ekle". Başlık ne yapılamayacağını
            // yazıyordu (kopya kuralına ters), altyazı düğmenin tekrarıydı.
            Text(emptyTitle)
                .displayLG()
                .foregroundColor(V3Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)

            if canAddMoment {
                V3PrimaryButton(
                    title: NSLocalizedString("archive.addNow", comment: ""),
                    isFullWidth: true
                ) {
                    onAddMoment?()
                }
                .padding(.top, V3Tokens.spacingSM)
            }
        }
    }

    /// Bugün → ne yapılacağını yazar. Geçmiş gün → retroaktif an eklenmediği
    /// için yapılacak bir şey yok; durum olduğu gibi söyleniyor.
    private var emptyTitle: String {
        NSLocalizedString(
            isToday ? "archive.dayEmpty.today" : "archive.dayEmpty.past",
            comment: ""
        )
    }

    private var dateLabel: String {
        let f = ONEFormatters.dayMonth
        return f.string(from: day.date).uppercased()
    }

}

// MARK: - Scroll offset probe

private struct DayDetailScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
