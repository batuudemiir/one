//
//  V3ArchiveView.swift
//  one
//
//  v3 arşiv — talimat spec:
//   - Üstte Ay/Yıl segment (soft kapsül, aktif: bg + shadow)
//   - ‹ ay adı 32px › nav satırı
//   - Meta: "N gün · N an · en çok X" (DM Mono 11)
//   - Hafta başlıkları (Pt Sa Ça Pe Cu Ct Pz, DM Mono 10, faint)
//   - 7-col grid, gap 6, radius 9 — DayFill hücreler
//   - Boş gün: DayFill kesikli çerçeve
//   - Seçili gün: çift halka
//

import SwiftUI

struct V3ArchiveView: View {
    let months: [MonthSummary]
    /// Aktif ay (0-indexli); nav butonları güncelleyecek.
    @State private var monthIndex: Int = Calendar.current.component(.month, from: Date()) - 1
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var view: ArchiveViewMode = .month
    /// Üst çubuğun 0→1 zemin/başlık ilerlemesi. Scroll offset'inden geliyor.
    @State private var topBarProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Bir güne dokunulduğunda parent'a haber.
    var onDayTap: ((Date, [Moment]) -> Void)? = nil
    /// Parent'ın full-detail overlay'de gösterdiği tarih. Bu tarihe eşit
    /// grid hücresi hero morph'un kaynağı; başkaları normal görünüyor.
    var heroDate: Date? = nil

    /// Grid ↔ detay morph için ortak namespace (ArchiveContainerView inject eder).
    @Environment(\.archiveDayNamespace) private var envDayNS
    @Namespace private var localDayNS
    private var dayNS: Namespace.ID { envDayNS ?? localDayNS }

    enum ArchiveViewMode { case month, year }

    /// Hiç veri var mı? Boş arşiv özel state gösterir.
    private var isCompletelyEmpty: Bool {
        months.allSatisfy { $0.filledDays == 0 }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Sekme tekrar dokunulunca buraya scrollTo edilecek anchor.
                    // Aynı zamanda scroll-driven tab-bar minimize sensörü —
                    // GeometryReader burada oturur ki content offset'i okunsun.
                    Color.clear.frame(height: 0)
                        .id("archiveTop")
                        .scrollOffsetSensor(spaceName: "one.scroll.archive")

                    if isCompletelyEmpty {
                        emptyArchive
                            .padding(.top, 60)
                    } else {
                        // Scroll-driven shrink: Ay/Yıl segmenti aşağı kaydırdıkça
                        // hafifçe küçülür ve soluklaşır. Instagram Profile hissi.
                        // `scrollTransition` closure'ı @Sendable — main
                        // actor'a bağlı `reduceMotion`'ı içeriden okuyamaz,
                        // değeri dışarıda yakalıyoruz.
                        let shrink: CGFloat = reduceMotion ? 0 : 0.05
                        segmentControl
                            .padding(.top, V3Tokens.spacingXL)
                            .scrollTransition(axis: .vertical) { view, phase in
                                let up = max(0, -phase.value)
                                return view
                                    .opacity(1 - up * 0.75)
                                    // Reduce Motion: scale düşer, opacity kalır.
                                    .scaleEffect(1 - up * shrink, anchor: .top)
                            }

                        switch view {
                        case .month:
                            monthContent
                        case .year:
                            yearContent
                        }
                    }
                }
                .padding(.horizontal, V3Tokens.channel)
                .padding(.top, 6)
                // Dinlenme pozisyonunun tek sahibi kabuk: `safeAreaInset`
                // nav yüksekliği kadar pay bırakıyor. Buradaki fazladan 24pt
                // o payın üstüne biniyordu — son satır çubuğun 16pt üstünde
                // duruyor, çubuk boş kağıdın üzerinde asılı kalıyordu. Cam
                // ancak arkasından bir şey geçerse cam gibi okunur.
            }
            .background(V3Tokens.paper)
            .hidesTabBarOnScroll(tab: .archive, spaceName: "one.scroll.archive")
            .topBarProgress($topBarProgress, spaceName: "one.scroll.archive")
            .safeAreaInset(edge: .top, spacing: 0) {
                // Başlık sekmenin adı ve artık **her zaman** görünüyor.
                // Kaydırınca beliren başlık burada özellikle kötüydü: Arşiv'in
                // gövdesi segment kontrolüyle başlıyor, yani ekran durağan
                // haldeyken adı hiçbir yerde yazmıyordu.
                //
                // Bağlam yok — bakılan ay gövdedeki damgada duruyor. Çubuğa
                // da yazılsaydı aynı kelime ~50pt arayla iki kez okunurdu ve
                // damga İngilizce ("August"), çubuk yerelleştirilmiş
                // ("Ağustos") olduğu için iki dilde.
                //
                // Sağdaki eylem Yankı: arşiv geriye bakma yüzeyi, aylık özet
                // de öyle. Eskiden yalnız Profil'in ortasındaki bir kartın
                // arkasındaydı.
                V3TopBar(
                    style: .root,
                    title: PrimaryTab.archive.screenTitle,
                    progress: topBarProgress
                ) {
                    V3TopBarIconButton(
                        systemName: "sparkles",
                        label: NSLocalizedString("topbar.monthlyEcho", comment: "")
                    ) {
                        NotificationCenter.default.post(name: .init("switchToEchoTab"), object: nil)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .archiveTabRetapped)) { _ in
                withAnimation(ONEAnimation.easing) {
                    proxy.scrollTo("archiveTop", anchor: .top)
                }
            }
        }
    }

    // MARK: - Empty archive (spec: 28 dashed squares, ilk kor kenarlı)

    private var emptyArchive: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            Text(NSLocalizedString("archive.empty.title", comment: ""))
                .font(ONEBrand.display(34))
                .tracking(-1.0)
                .foregroundColor(V3Tokens.ink)

            Text(NSLocalizedString("archive.empty.body", comment: ""))
                .bodyLG()
                .foregroundColor(V3Tokens.mutedText)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<28, id: \.self) { i in
                    RoundedRectangle(cornerRadius: V3Tokens.radiusMosaic, style: .continuous)
                        .strokeBorder(
                            i == 0 ? ONEBrand.kor : V3Tokens.hairline,
                            style: StrokeStyle(lineWidth: i == 0 ? 2 : 1.5, dash: i == 0 ? [] : [3, 3])
                        )
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(.top, 6)

            HStack(spacing: 10) {
                Circle().fill(ONEBrand.kor).frame(width: 5, height: 5)
                Text(NSLocalizedString("archive.todayWaiting", comment: ""))
                    .bodySMMedium()
                    .foregroundColor(V3Tokens.mutedText)
            }
            .padding(.top, V3Tokens.spacingSM)

            Button {
                NotificationCenter.default.post(name: .init("switchToTodayTab"), object: nil)
            } label: {
                Text(NSLocalizedString("archive.addMoment", comment: ""))
                    .bodyLGSemibold()
                    .foregroundColor(V3Tokens.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Capsule(style: .continuous).fill(V3Tokens.ink))
            }
            .buttonStyle(.onePressable)
            .padding(.top, V3Tokens.spacingMD)
        }
    }

    // MARK: - Segment

    private var segmentControl: some View {
        HStack(spacing: 6) {
            segButton(NSLocalizedString("archive.seg.month", comment: ""), isOn: view == .month) {
                ONEHaptics.toggle()
                withAnimation(ONEAnimation.easing) { view = .month }
            }
            segButton(NSLocalizedString("archive.seg.year", comment: ""), isOn: view == .year) {
                ONEHaptics.toggle()
                withAnimation(ONEAnimation.easing) { view = .year }
            }
        }
        .padding(5)
        .background(
            Capsule(style: .continuous).fill(V3Tokens.wash)
        )
    }

    private func segButton(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(V3Typography.sans(14, weight: isOn ? .semibold : .medium))
                .foregroundColor(isOn ? V3Tokens.ink : V3Tokens.mutedText)
                .frame(maxWidth: .infinity)
                // 11pt idi → ~39pt yükseklik, 44pt hedefin altında.
                .padding(.vertical, 14)
                .background(
                    Group {
                        if isOn {
                            // Gölge kaldırıldı: v3'te gölge yalnız yüzen
                            // sekme çubuğu ve cam sheet'lerde. Aktif durumu
                            // `paper` dolgu + hairline kenar taşıyor.
                            Capsule(style: .continuous)
                                .fill(V3Tokens.paper)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(V3Tokens.hairline, lineWidth: 1)
                                )
                        }
                    }
                )
                .frame(minHeight: 44)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.onePressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Month content

    private var monthContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            monthHeader
                .padding(.top, V3Tokens.spacingXL)

            metaRow
                .padding(.top, V3Tokens.spacingLG)

            weekHeaders
                .padding(.top, V3Tokens.spacingXL)

            mosaicGrid
                .padding(.top, 10)

        }
    }

    /// Ayın masthead'i — ekranın en iri öğesi.
    ///
    /// Burada `V3HandText.month(monthDate, size: 40)` vardı: Caveat Brush
    /// ile, her dilde İngilizce ("August"), iki chevron'un ortasında. Üç
    /// ayrı sorun:
    ///
    ///  1. **Yüz.** `V3Typography.hand`'in kendi belgesi el yazısını
    ///     "gövde metni, buton, **ekran başlığı**: asla" diye sınırlıyor —
    ///     ve uygulamada o role kalan tek çağrı buydu. Arşiv'in en iri
    ///     öğesi, başka hiçbir ekranda geçmeyen bir yüzle çiziliyordu.
    ///     Damga kuralı bir *fotoğrafa basılan tarih* için yazılmıştı;
    ///     ekranın kendi adı damga değil.
    ///  2. **Dil.** Türkçe arayüzde "August". Üstelik damga VoiceOver'dan
    ///     gizli olduğu için ay adı yalnız satırın `accessibilityLabel`'ında
    ///     duruyordu — görsel metin ile okunan metin iki ayrı dildeydi.
    ///  3. **Yıl hiç yoktu.** Ocak'tan geriye gidince `year` azalıyor ama ay
    ///     görünümünde yılı söyleyen tek bir işaret yok: 2025 Ağustos'u
    ///     2026 Ağustos'undan ayırt edilemiyordu. "Neredeyim?" sorusunun
    ///     cevabı eksikti.
    ///
    /// Yüz artık `displayHero()` — Arşiv'in `emptyArchive` ve `yearContent`
    /// başlıkları da bu ailede, gün detayının büyük başlığı da aynı kademe.
    /// Yıl `display` değil mono: aynı satırda iki masthead olmasın, ve yıl
    /// okunan bir ad değil bir **veri** — mono zaten o register.
    ///
    /// Chevron'lar sağda yan yana. Ekranın iki ucuna dağılmış hâlleri ne bir
    /// grup olarak okunuyordu ne de tek elle erişiliyordu; başlığı da
    /// ortada sıkıştırıyorlardı.
    private var monthHeader: some View {
        HStack(spacing: V3Tokens.spacingMD) {
            HStack(alignment: .firstTextBaseline, spacing: V3Tokens.spacingSM) {
                Text(monthName)
                    .displayHero()
                    .foregroundColor(V3Tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(verbatim: String(year))
                    .monoSM(weight: .regular)
                    .monospacedDigit()
                    .foregroundColor(V3Tokens.faintText)
            }

            Spacer(minLength: V3Tokens.spacingSM)

            HStack(spacing: 0) {
                navButton(
                    symbol: "chevron.left",
                    label: NSLocalizedString("archive.previousMonth", comment: ""),
                    action: prevMonth
                )
                navButton(
                    symbol: "chevron.right",
                    label: NSLocalizedString("archive.nextMonth", comment: ""),
                    action: nextMonth
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(monthName) \(year)")
    }

    /// Ay ileri/geri. `label` zorunlu: SF Symbol'ün kendi tanımı VoiceOver'da
    /// "chevron left" diye okunuyordu, "Önceki ay" değil.
    ///
    /// Görsel çerçeve 40pt, dokunma hedefi 44pt — `V3TopBarIconButton`'daki
    /// kalıbın aynısı.
    private func navButton(
        symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .iconMD(weight: .medium)
                .foregroundColor(V3Tokens.mutedText)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: V3Tokens.radiusCard, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.onePressable)
        .accessibilityLabel(label)
    }

    /// Bakılan ayın ilk günü. Hem yerelleştirilmiş `monthName` hem de
    /// el yazısı damgası bunu okuyor — tarih kurulumu tek yerde.
    private var monthDate: Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = monthIndex + 1
        comps.day = 1
        return Calendar.current.date(from: comps) ?? Date()
    }

    /// Kullanıcının dilinde ay adı — masthead ve VoiceOver aynı dizeyi
    /// okuyor. `monthName` (MMMM) değil `monthStandalone` (LLLL): burada ay
    /// bir tarihin içinde çekimlenmiyor, tek başına duruyor ve bazı diller
    /// bu iki durumu farklı yazıyor.
    private var monthName: String {
        ONEFormatters.monthStandalone.string(from: monthDate)
    }

    private var currentSummary: MonthSummary? {
        months.first(where: { $0.year == year && $0.month == monthIndex + 1 })
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            let filled = currentSummary?.filledDays ?? 0
            let entryCount = currentSummary?.entries.values.reduce(0) { $0 + $1.count } ?? 0
            let topMood = topMoodLabel

            Text(String(format: NSLocalizedString("archive.dayCount", comment: ""), filled))
            Text("·")
            Text("\(entryCount) an")
            if let topMood {
                Text("·")
                Text(String(format: NSLocalizedString("archive.mostFrequent", comment: ""), topMood))
            }
            Spacer()
        }
        .monoSM(weight: .regular)
        .tracking(1.2)
        .textCase(.uppercase)
        .foregroundColor(V3Tokens.faintText)
        // Beş ayrı Text idi; VoiceOver ayırıcı noktaları da ayrı öğe olarak
        // okuyordu ("orta nokta"). Tek öğe, tek cümle.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metaRowA11y)
    }

    private var metaRowA11y: String {
        let filled = currentSummary?.filledDays ?? 0
        let entryCount = currentSummary?.entries.values.reduce(0) { $0 + $1.count } ?? 0
        var text = String(format: NSLocalizedString("archive.a11y.meta", comment: ""), filled, entryCount)
        if let topMood = topMoodLabel { text += String(format: NSLocalizedString("archive.a11y.metaTop", comment: ""), topMood) }
        return text
    }

    private var topMoodLabel: String? {
        guard let summary = currentSummary,
              let topHex = summary.moodDistribution.first?.color,
              let mood = V3Mood.fromHex(topHex) else { return nil }
        return mood.label.lowercased()
    }

    /// Gün başlıkları takvimden — dokuz dile elle kısaltma yazmak yerine
    /// `Calendar` locale'i veriyor. Pazartesi başlangıçlı.
    private static var weekHeaderSymbols: [String] {
        var cal = Calendar.current
        cal.locale = LanguageManager.shared.currentLocale
        let symbols = cal.veryShortWeekdaySymbols      // Pazar başlangıçlı
        return (0..<7).map { symbols[($0 + 1) % 7] }
    }

    private var weekHeaders: some View {
        HStack(spacing: 6) {
            ForEach(Array(Self.weekHeaderSymbols.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .monoLabel(weight: .regular)
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundColor(V3Tokens.faintText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Mosaic grid

    private var mosaicGrid: some View {
        let cells = calendarCells
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                cellView(cell)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    /// Ay için 7-kolon grid — leading blank cells for day-of-week offset.
    private var calendarCells: [CalCell] {
        var comps = DateComponents()
        comps.year = year
        comps.month = monthIndex + 1
        comps.day = 1
        let cal = Calendar.current
        guard let firstDay = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstDay) else {
            return []
        }
        let weekday = cal.component(.weekday, from: firstDay)
        // Weekday: 1=Sun, 2=Mon, ... 7=Sat. Pt=Mon → offset from Monday.
        let offset = (weekday + 5) % 7
        var out: [CalCell] = Array(repeating: .empty, count: offset)
        for day in range {
            var dc = DateComponents()
            dc.year = year; dc.month = monthIndex + 1; dc.day = day
            let date = cal.date(from: dc) ?? Date()
            let entries = currentSummary?.allEntries(for: date) ?? []
            out.append(.day(date: date, hexes: entries.map(\.moodColorHex)))
        }
        return out
    }

    enum CalCell {
        case empty
        case day(date: Date, hexes: [String])
    }

    @ViewBuilder
    private func cellView(_ cell: CalCell) -> some View {
        switch cell {
        case .empty:
            Color.clear
        case .day(let date, let hexes):
            let isHero = heroDate == date
            let cellID = V3ArchiveView.cellMorphID(for: date)
            let isEmpty = hexes.isEmpty
            // Dokunmak günü **açar**. Eskiden hücre yalnız `selectedDay`'i
            // kilitliyor, mozaiğin altında tarih + "N an" yazan bir özet kartı
            // beliriyordu; gerçek gün detayına ancak o kartın içindeki soluk
            // "Detay" çipinden geçiliyordu. Yani iki dokunuş ve bir ara ekran,
            // ve ara ekran detayın gösterdiğinin sıkı bir alt kümesini
            // gösteriyordu. Ara adım kalktı — hero morph zaten bu yol için
            // kurulmuştu (`heroDate` kaynağı gizler, detay hedefi çizer).
            Button {
                ONEHaptics.pick()
                onDayTap?(date, [])
            } label: {
                DayFill(hexes: hexes, cornerRadius: V3Tokens.radiusMosaic)
                    // Her hücreye tarih-bazlı UNIQUE ID veriyoruz. Detay hero'su
                    // aynı ID ile geldiğinde SwiftUI eşleştirip morph ediyor.
                    // Aynı ID'yi birden fazla kaynağa vermek belirsiz davranış
                    // yaratır; unique ID bunu önlüyor.
                    .matchedGeometryEffect(id: cellID, in: dayNS, isSource: !isHero)
                    .opacity(isHero ? 0 : 1)
            }
            // Hücre görseli ızgaranın kendi ölçüsünde (dar cihazda ~34pt);
            // dokunma hedefi görünmez şekilde 44pt'ye tamamlanıyor.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(.onePressable)
            .accessibilityLabel(cellA11y(date, hexes: hexes))
            // Uzun basınca çıkan menü kaldırıldı: tek maddesi "o güne an
            // ekle"ydi, yani geriye dönük giriş. Duruş ilke 3 — boşluk
            // kalıcıdır, arşiv doğru olduğu için değerli. Hücreye dokunmak
            // günün detayını açar; geçmiş bir güne yazmanın yolu yok.
        }
    }

    /// Tarih-bazlı morph ID. V3DayDetailView aynı formülle üretiyor.
    static func cellMorphID(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        return "archiveDayHero-\(Int(day.timeIntervalSince1970))"
    }

    /// Mozaikte gün hücresinin tek anlam taşıyıcısı **renk** — VoiceOver
    /// kullanıcısı için o renk hiç yok. Etiket bu yüzden mood adlarını
    /// açıkça söylüyor; birden çok an varsa hepsini sırayla, çünkü "3 an"
    /// tek başına günün nasıl geçtiğini anlatmıyor.
    private func cellA11y(_ date: Date, hexes: [String]) -> String {
        let day = Calendar.current.component(.day, from: date)
        if hexes.isEmpty { return String(format: NSLocalizedString("archive.a11y.cellEmpty", comment: ""), day) }

        let moods = hexes.compactMap { V3Mood.fromHex($0)?.label }
        if moods.isEmpty { return String(format: NSLocalizedString("archive.a11y.cellCount", comment: ""), day, hexes.count) }
        if moods.count == 1 { return String(format: NSLocalizedString("archive.a11y.cellOne", comment: ""), day, moods[0]) }
        // "14, 3 an: enerjik, odaklı, huzurlu"
        return String(format: NSLocalizedString("archive.a11y.cellMany", comment: ""), day, hexes.count, moods.joined(separator: ", "))
    }

    // MARK: - Year content

    private var yearContent: some View {
        VStack(alignment: .leading, spacing: V3Tokens.spacingXL) {
            Text("\(year)")
                .font(ONEBrand.display(40))
                .tracking(-1.2)
                .foregroundColor(V3Tokens.ink)
                .padding(.top, V3Tokens.spacingXL)

            let cols = Array(repeating: GridItem(.flexible(), spacing: V3Tokens.spacingMD), count: 3)
            LazyVGrid(columns: cols, spacing: V3Tokens.spacingXL) {
                ForEach(0..<12, id: \.self) { m in
                    Button {
                        monthIndex = m
                        withAnimation(ONEAnimation.easing) { view = .month }
                    } label: {
                        yearMonthMini(m)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.onePressable)
                }
            }
        }
    }

    private func yearMonthMini(_ m: Int) -> some View {
        let summary = months.first(where: { $0.year == year && $0.month == m + 1 })
        let cells = miniCells(year: year, monthIdx: m, summary: summary)
        return VStack(alignment: .leading, spacing: V3Tokens.spacingSM) {
            Text(shortMonthName(m))
                .monoLabel(weight: .regular)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundColor(V3Tokens.faintText)
            let miniCols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
            LazyVGrid(columns: miniCols, spacing: 2) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, hexes in
                    DayFill(hexes: hexes, cornerRadius: V3Tokens.radiusMicro)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func miniCells(year: Int, monthIdx: Int, summary: MonthSummary?) -> [[String]] {
        var comps = DateComponents()
        comps.year = year; comps.month = monthIdx + 1; comps.day = 1
        let cal = Calendar.current
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let weekday = cal.component(.weekday, from: first)
        let offset = (weekday + 5) % 7
        var out: [[String]] = Array(repeating: [], count: offset)
        for day in range {
            var dc = DateComponents(); dc.year = year; dc.month = monthIdx + 1; dc.day = day
            let date = cal.date(from: dc) ?? Date()
            let entries = summary?.allEntries(for: date) ?? []
            out.append(entries.map(\.moodColorHex))
        }
        return out
    }

    private func shortMonthName(_ m: Int) -> String {
        let f = ONEFormatters.monthShort
        var comps = DateComponents(); comps.year = year; comps.month = m + 1; comps.day = 1
        let date = Calendar.current.date(from: comps) ?? Date()
        return f.string(from: date)
    }

    // MARK: - Nav

    private func prevMonth() {
        ONEHaptics.nudge()
        withAnimation(ONEAnimation.easing) {
            if monthIndex == 0 {
                monthIndex = 11
                year -= 1
            } else {
                monthIndex -= 1
            }
        }
    }

    private func nextMonth() {
        ONEHaptics.nudge()
        withAnimation(ONEAnimation.easing) {
            if monthIndex == 11 {
                monthIndex = 0
                year += 1
            } else {
                monthIndex += 1
            }
        }
    }
}
