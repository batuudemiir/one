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

    /// Alt ekranlar. Prototipte arşiv → yıl → gün üç kademeli bir iniş;
    /// sekme çubuğu bu ekranlarda kalıyor (sheet değil, aynı yığın).
    @State private var showYear = false
    @State private var selectedDay: DailyEntry? = nil

    init(context: NSManagedObjectContext) {
        _archiveStore = StateObject(wrappedValue: ArchiveStore(context: context))
    }

    var body: some View {
        ZStack {
            ONETokens.oneCream.ignoresSafeArea()

            if archiveStore.isLoading && archiveStore.yearData.isEmpty {
                ArchiveSkeletonView()
            } else {
                ArchiveMosaicView(
                    months: archiveStore.yearData,
                    lastYearToday: archiveStore.lastYearToday,
                    onDayTap: { selectedDay = $0 },
                    onYearTap: { showYear = true }
                )
            }

            if showYear {
                YearOverviewView(
                    months: archiveStore.yearData,
                    onBack: { showYear = false }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(1)
            }

            if let day = selectedDay {
                DayDetailView(
                    entry: day,
                    onBack: { selectedDay = nil },
                    circleColors: []
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: showYear)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: selectedDay)
        .task { await archiveStore.loadDataAsync() }
        .onReceive(NotificationCenter.default.publisher(for: .init("todaySongSaved"))) { _ in
            Task { await archiveStore.loadDataAsync() }
        }
        // NavigationStack kaldırıldı — DayDetailView artık kullanılmıyor
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
                            .fill(ONETokens.onePaper)
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
