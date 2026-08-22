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
    @State private var selectedDay: Date? = nil
    /// Üst çubuğun 0→1 zemin/başlık ilerlemesi. Scroll offset'inden geliyor.
    @State private var topBarProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Bir güne dokunulduğunda parent'a haber.
    var onDayTap: ((Date, [Moment]) -> Void)? = nil
    /// "Poster" butonu — Faz 7 (Yankı) tarafından bağlanacak.
    var onPoster: (() -> Void)? = nil
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
                // Başlık sekmenin adı. Bir ara "bakılan dönem" yazıyordu
                // ama gövdedeki damga İngilizce ("August"), çubuk
                // yerelleştirilmiş ("Ağustos") — aralarında ~50pt vardı ve
                // aynı ekranda iki dilde aynı kelime hata gibi okunuyordu.
                // Damga kullanıcı kararı, çakışmayı çubuk taraftan çözüyoruz.
                V3TopBar(
                    leading: .mark,
                    title: PrimaryTab.archive.title,
                    progress: topBarProgress
                )
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
                Text("An ekle")
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
            segButton("Ay", isOn: view == .month) {
                ONEHaptics.toggle()
                withAnimation(ONEAnimation.easing) { view = .month }
            }
            segButton("Yıl", isOn: view == .year) {
                ONEHaptics.toggle()
                withAnimation(ONEAnimation.easing) { view = .year; selectedDay = nil }
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
            HStack {
                navButton(symbol: "chevron.left", label: NSLocalizedString("archive.previousMonth", comment: ""), action: prevMonth)
                Spacer()
                // El yazısı damga — her dilde İngilizce, VoiceOver'dan gizli.
                // Okunacak ay adı bu satırın label'ında, kullanıcının dilinde.
                V3HandText.month(monthDate, size: 40, alignment: .leading)
                Spacer()
                navButton(symbol: "chevron.right", label: NSLocalizedString("archive.nextMonth", comment: ""), action: nextMonth)
            }
            .padding(.top, V3Tokens.spacingXL)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(monthName)

            metaRow
                .padding(.top, V3Tokens.spacingLG)

            weekHeaders
                .padding(.top, V3Tokens.spacingXL)

            mosaicGrid
                .padding(.top, 10)

            if let selectedDay {
                dayDetailInline(selectedDay)
                    .padding(.top, V3Tokens.spacingXL2)
            }
        }
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
                .font(.system(size: 14, weight: .medium))
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

    /// Kullanıcının dilinde ay adı — üst çubuk başlığı ve VoiceOver.
    /// Ekrandaki iri başlık İngilizce damga; bu ikisi bilinçli farklı.
    private var monthName: String {
        ONEFormatters.monthName.string(from: monthDate)
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
        .font(V3Typography.mono(11, weight: .regular))
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
        var text = "\(filled) gün, \(entryCount) an"
        if let topMood = topMoodLabel { text += ", en çok \(topMood)" }
        return text
    }

    private var topMoodLabel: String? {
        guard let summary = currentSummary,
              let topHex = summary.moodDistribution.first?.color,
              let mood = V3Mood.fromHex(topHex) else { return nil }
        return mood.label.lowercased()
    }

    private var weekHeaders: some View {
        HStack(spacing: 6) {
            ForEach(["Pt","Sa","Ça","Pe","Cu","Ct","Pz"], id: \.self) { label in
                Text(label)
                    .font(V3Typography.mono(10, weight: .regular))
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
            let isSelected = selectedDay == date
            let isHero = heroDate == date
            let cellID = V3ArchiveView.cellMorphID(for: date)
            let isEmpty = hexes.isEmpty
            Button {
                ONEHaptics.pick()
                withAnimation(ONEAnimation.easingChip) {
                    if selectedDay == date { selectedDay = nil }
                    else { selectedDay = date }
                }
            } label: {
                DayFill(hexes: hexes, cornerRadius: V3Tokens.radiusMosaic)
                    .overlay(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: V3Tokens.radiusMosaic, style: .continuous)
                                    .strokeBorder(V3Tokens.paper, lineWidth: 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: V3Tokens.radiusMosaic, style: .continuous)
                                            .strokeBorder(V3Tokens.ink, lineWidth: 2)
                                            .padding(2)
                                    )
                            }
                        }
                    )
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
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .contextMenu {
                if !isEmpty {
                    Button {
                        // "Detay" — parent'a delegasyon (bugüne hero morph).
                        onDayTap?(date, [])
                    } label: {
                        Label("Detay", systemImage: "square.split.bottomrightquarter")
                    }
                }
                Button {
                    // v3 spec: geçmiş gün için An akışı past-day mode.
                    GlobalUIState.shared.pendingEntryDate = Calendar.current.startOfDay(for: date)
                    NotificationCenter.default.post(name: .init("switchToTodayTab"), object: nil)
                } label: {
                    Label(isEmpty ? "Bu güne an ekle" : "Yeni an ekle",
                          systemImage: "plus.circle")
                }
            }
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
        if hexes.isEmpty { return "\(day), boş" }

        let moods = hexes.compactMap { V3Mood.fromHex($0)?.label }
        if moods.isEmpty { return "\(day), \(hexes.count) an" }
        if moods.count == 1 { return "\(day), \(moods[0])" }
        // "14, 3 an: enerjik, odaklı, huzurlu"
        return "\(day), \(hexes.count) an: \(moods.joined(separator: ", "))"
    }

    // MARK: - Inline day detail

    private func dayDetailInline(_ date: Date) -> some View {
        // Container'daki full V3DayDetailView'e delegate et — inline özet.
        let entries = currentSummary?.allEntries(for: date) ?? []
        let moments = entries.compactMap { entry -> Moment? in
            // DailyEntry → Moment shim (Persistence çevirimi yerine inline)
            // Note: for now just pass to onDayTap; full inline expansion is polish.
            _ = entry
            return nil
        }
        return VStack(alignment: .leading, spacing: V3Tokens.spacingMD) {
            HStack {
                Text(fullDateLabel(date))
                    .font(V3Typography.display(20, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundColor(V3Tokens.ink)
                Spacer()
                Button {
                    // Full detay ekranını aç.
                    onDayTap?(date, moments)
                } label: {
                    Text("Detay")
                        .bodyXSSemibold()
                        .foregroundColor(V3Tokens.mutedText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .overlay(
                            Capsule().stroke(V3Tokens.hairline, lineWidth: 1)
                        )
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.onePressable)
            }
            Text(String(format: NSLocalizedString("archive.momentsOnDay", comment: ""), entries.count))
                .bodySM()
                .foregroundColor(V3Tokens.mutedText)
                .contentTransition(.numericText())
                .animation(ONEAnimation.easingChip, value: entries.count)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        )
    }

    private func fullDateLabel(_ date: Date) -> String {
        let f = ONEFormatters.dayMonth
        return f.string(from: date)
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
                .font(V3Typography.mono(10, weight: .regular))
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
            selectedDay = nil
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
            selectedDay = nil
        }
    }
}
