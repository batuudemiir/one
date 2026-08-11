//
//  ArchiveView.swift
//  One - Günlük Mood
//

import SwiftUI
import CoreData

/// Arşiv kabuğu. Prototipte ay/yıl geçişi yok — tek sürekli akış.
/// Ay/yıl geçişli eski görünümler (MonthArchiveView, YearArchiveView)
/// silindi — prototipte karşılıkları yok.
struct ArchiveContainerView: View {
    @StateObject private var archiveStore: ArchiveStore
    private let context: NSManagedObjectContext

    /// Gün detayı overlay — mozaikte bir güne tıklanınca açılır.
    /// (Yıl/Ay geçişi artık V3ArchiveView içinde segment control ile.)
    @State private var selectedDate: Date? = nil

    /// Seçili günün anları.
    ///
    /// Eskiden `body` içinde, `if let date = selectedDate` bloğunda
    /// `fetchMoments(...)` çağrılıyordu. Bu SwiftUI'de "her yeniden çizimde
    /// SQLite'a git" demek — ve detay tam da `spring(0.44)` hero morph'u
    /// oynarken açıldığı için sorgu o animasyonun her karesinde koşuyordu.
    /// Artık gün değişince bir kez yükleniyor.
    @State private var selectedMoments: [Moment] = []

    /// Grid hücresi ↔ V3DayDetailView hero morph için ortak namespace.
    @Namespace private var archiveDayNS
    /// DayPreviewCard fotoğraf ↔ FullScreenPhotoView morph namespace.
    @Namespace private var archivePhotoNS

    init(context: NSManagedObjectContext) {
        _archiveStore = StateObject(wrappedValue: ArchiveStore(context: context))
        self.context = context
    }

    var body: some View {
        ZStack {
            V3Tokens.paper.ignoresSafeArea()

            if archiveStore.isLoading && archiveStore.yearData.isEmpty {
                ArchiveSkeletonView()
            } else {
                // v3 arşiv: segment (Ay/Yıl) + prototipe uyumlu mozaik.
                V3ArchiveView(
                    months: archiveStore.yearData,
                    onDayTap: { date, _ in
                        // Fetch animasyondan ÖNCE: `onChange(of: selectedDate)`
                        // ile yükleseydik detay ilk karesini boş listeyle
                        // çizerdi. Tek sorgu, morph başlamadan.
                        let moments = PersistenceController.shared.fetchMoments(for: date, context: context)
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
                            selectedMoments = moments
                            selectedDate = date
                        }
                    },
                    onPoster: { /* Phase 7 wiring */ },
                    heroDate: selectedDate
                )
            }

            if let date = selectedDate {
                // v3: gün detayı artık TÜM anları listeler (multi-moment).
                V3DayDetailView(
                    day: Day(date: Calendar.current.startOfDay(for: date), moments: selectedMoments),
                    onBack: {
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
                            selectedDate = nil
                        }
                    },
                    onAddMoment: {
                        // v3: An akışını past-day mode ile aç. TodayView
                        // GlobalUIState.pendingEntryDate'i tüketir ve entryDay
                        // olarak V3EntryContainer'a geçirir.
                        GlobalUIState.shared.pendingEntryDate = Calendar.current.startOfDay(for: date)
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
                            selectedDate = nil
                        }
                        NotificationCenter.default.post(name: .init("switchToTodayTab"), object: nil)
                    }
                )
                .transition(.opacity)
                .zIndex(2)
            }
        }
        // Sekme artık `TabView` içinde canlı kaldığı için `archiveStore` de
        // korunuyor. `.task` yine de sekme yeniden kurulursa (scene reload,
        // örnek veri anahtarı) çalışabilir — o yüzden guard'lı: elde veri
        // varsa 12 aylık fetch'i tekrarlama. Tazeleme `todaySongSaved`
        // bildirimiyle zaten geliyor.
        .task {
            guard archiveStore.yearData.isEmpty else { return }
            await archiveStore.loadDataAsync()
        }
        // Detay kapanınca boşalt — bir sonraki açılışta önceki günün anları
        // bir kare boyunca görünmesin. Doldurma `onDayTap`'te.
        .onChange(of: selectedDate) { _, date in
            if date == nil { selectedMoments = [] }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("todaySongSaved"))) { _ in
            Task { await archiveStore.loadDataAsync() }
            // Detay açıkken yeni bir an kaydedildiyse (past-day akışı o günü
            // hedefliyor olabilir) listedeki anlar bayat kalmasın.
            if let date = selectedDate {
                selectedMoments = PersistenceController.shared.fetchMoments(for: date, context: context)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .archiveTabRetapped)) { _ in
            if selectedDate != nil {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.88)) {
                    selectedDate = nil
                }
            }
        }
        .environment(\.archiveDayNamespace, archiveDayNS)
        .environment(\.archivePhotoNamespace, archivePhotoNS)
        .environmentObject(archiveStore)
    }
}

// MARK: - Skeleton

struct ArchiveSkeletonView: View {
    @State private var shimmerOpacity: Double = 0.4

    private let columns = 7
    private let rows = 5

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 8) {
                    ForEach(0..<columns, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(V3Tokens.surface)
                            .frame(height: 36)
                            .opacity(shimmerOpacity)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
            ) {
                shimmerOpacity = 0.9
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ArchiveContainerView(context: PersistenceController.preview.container.viewContext)
}
