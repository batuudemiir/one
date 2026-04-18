//
//  MonthlySummaryView.swift
//  one
//
//  Aylık özet tam ekran, TabView (.page) ile yatay kaydırma.
//  3 sayfa: Kapak → Ruh Hali Haritası → Top Şarkılar
//  Gerçek veriler CoreData'dan çekilir.
//  Paylaş butonu: aktif sayfayı render edip Instagram Story'e gönderir.
//

import SwiftUI
import CoreData

struct MonthlySummaryView: View {
    var data: MonthlySummaryData?
    var context: NSManagedObjectContext?

    @StateObject private var vm: MonthlySummaryViewModel
    @Environment(\.dismiss) private var dismiss

    // Aktif sekme takibi
    @State private var currentPage: Int = 0

    // Paylaş state
    @State private var isSharing   = false
    @State private var showPicker  = false

    // MARK: — Inits
    init(context: NSManagedObjectContext) {
        self.context = context
        self.data    = nil
        let cal   = Calendar.current
        _vm = StateObject(wrappedValue: MonthlySummaryViewModel(
            context: context,
            year:    cal.component(.year,  from: Date()),
            month:   cal.component(.month, from: Date())
        ))
    }

    init(data: MonthlySummaryData) {
        self.data    = data
        self.context = nil
        let cal = Calendar.current
        _vm = StateObject(wrappedValue: MonthlySummaryViewModel(
            context: PersistenceController.preview.container.viewContext,
            year:    cal.component(.year,  from: Date()),
            month:   cal.component(.month, from: Date())
        ))
    }

    private var displayData: MonthlySummaryData {
        if context != nil {
            return vm.summaryData ?? emptyData
        }
        return data ?? .mock
    }

    private var emptyData: MonthlySummaryData {
        let fmt = DateFormatter(); fmt.locale = LanguageManager.shared.currentLocale; fmt.dateFormat = "MMMM"
        let days = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
        return MonthlySummaryData(
            month:             fmt.string(from: Date()).capitalized,
            year:              Calendar.current.component(.year, from: Date()),
            totalDays:         days,
            uniqueArtists:     0,
            maxRepeat:         0,
            dominantMood:      "—",
            dominantMoodColor: .gray,
            dailyMoods:        Array(repeating: Color.gray.opacity(0.2), count: days),
            emotionBreakdown:  [(name: "—", percentage: 1.0, color: .gray.opacity(0.3))],
            topTracks:         [],
            totalEntries:      0,
            daysLogged:        0,
            monthStreak:       0
        )
    }

    // Sayfa etiketleri — picker için
    private let pageLabels = ["Kapak", "Ruh Hali", "Top Şarkılar"]
    private let pageIcons  = ["rectangle.portrait.fill", "calendar.badge.clock", "music.note.list"]

    var body: some View {
        ZStack {
            if vm.isLoading && data == nil {
                Color.black.ignoresSafeArea()
                ProgressView().tint(.white)
            } else {
                // TabView — selection ile aktif sayfa izleniyor
                TabView(selection: $currentPage) {
                    CoverCardView(data: displayData)
                        .tag(0)
                    MoodMapCardView(data: displayData)
                        .tag(1)
                    TopTracksCardView(data: displayData)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .ignoresSafeArea()
                .background(Color.black)
            }

            // ── Üst butonlar ──
            VStack {
                HStack {
                    // ✕ Kapat
                    Button { dismiss() } label: {
                        iconCircle("xmark")
                    }
                    Spacer()

                    // Paylaş — tek tık: aktif sayfa, uzun baskı: kart seçici
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        shareCard(page: currentPage)
                    } label: {
                        HStack(spacing: 6) {
                            if isSharing {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .bodyXS()
                                    .fontWeight(.semibold)
                            }
                            Text(NSLocalizedString("monthly.share", comment: ""))
                                .bodyXS()
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                        )
                    }
                    .disabled(isSharing)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showPicker = true
                        }
                    )
                }
                .padding(.top, 56)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .ignoresSafeArea()
        // ── Kart seçici sheet ──
        .confirmationDialog(NSLocalizedString("monthly.whichCard", comment: ""), isPresented: $showPicker, titleVisibility: .visible) {
            Button(NSLocalizedString("monthly.coverCard", comment: ""))       { shareCard(page: 0) }
            Button(NSLocalizedString("monthly.moodMapCard", comment: ""))     { shareCard(page: 1) }
            Button(NSLocalizedString("monthly.topTracksCard", comment: ""))   { shareCard(page: 2) }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
        }
        .onAppear {
            if context != nil { vm.load() }
            UIPageControl.appearance().currentPageIndicatorTintColor  = .white
            UIPageControl.appearance().pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.25)
        }
    }

    // MARK: — Yardımcı view
    private func iconCircle(_ name: String) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 36, height: 36)
            Image(systemName: name)
                .bodyXS()
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: — Kart render + Instagram Story paylaş
    private func shareCard(page: Int) {
        isSharing = true
        Task {
            let image = await renderCard(page: page)
            guard let image else { isSharing = false; return }

            await MainActor.run {
                shareToInstagramStory(image: image)
                isSharing = false
            }
        }
    }

    /// UIHostingController tabanlı render — GeometryReader içeren kartları da
    /// doğru boyutla render eder (ImageRenderer GeometryReader'ı çözemez).
    @MainActor
    private func renderCard(page: Int) async -> UIImage? {
        let d = displayData
        let cardSize   = CGSize(width: 390, height: 844)
        let topPad: CGFloat    = 60
        let bottomPad: CGFloat = 60
        let canvasSize = CGSize(width: 390, height: cardSize.height + topPad + bottomPad) // 390×964
        let scale = UIScreen.main.scale

        // 1. Build card view with watermark baked in
        let view: AnyView
        switch page {
        case 0:  view = AnyView(CoverCardView(data: d, showWatermark: true)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .background(Color.black))
        case 1:  view = AnyView(MoodMapCardView(data: d, isExport: true, showWatermark: true)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .background(Color.black))
        default: view = AnyView(TopTracksCardView(data: d, isExport: true, showWatermark: true)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .background(Color.black))
        }

        // 2. Render card at cardSize via UIHostingController
        let host = UIHostingController(rootView: view)
        host.view.frame = CGRect(origin: .zero, size: cardSize)
        host.view.backgroundColor = .black
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        // Give animations a moment to settle on export pass
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let cardImage = UIGraphicsImageRenderer(size: cardSize, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }

        // 3. Composite card onto a larger black canvas with top/bottom padding
        let finalImage = UIGraphicsImageRenderer(size: canvasSize, format: format).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))
            cardImage.draw(at: CGPoint(x: 0, y: topPad))
        }

        return finalImage
    }

    private func shareToInstagramStory(image: UIImage) {
        let urlStr = "instagram-stories://share?source_application=\(Bundle.main.bundleIdentifier ?? "com.batu.ones")"
        guard let url = URL(string: urlStr),
              UIApplication.shared.canOpenURL(url),
              let pngData = image.pngData() else {
            // Fallback → sistem sharesheet
            fallbackShare(image: image)
            return
        }
        UIPasteboard.general.setItems(
            [["com.instagram.sharedSticker.backgroundImage": pngData]],
            options: [.expirationDate: Date().addingTimeInterval(300)]
        )
        UIApplication.shared.open(url)
    }

    private func fallbackShare(image: UIImage) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root  = scene.windows.first?.rootViewController else { return }
        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let pop = av.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: UIScreen.main.bounds.midX,
                                    y: UIScreen.main.bounds.maxY, width: 0, height: 0)
        }
        root.present(av, animated: true)
    }
}

// MARK: — Previews
#Preview {
    MonthlySummaryView(data: .mock)
}
