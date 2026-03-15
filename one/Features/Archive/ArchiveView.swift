//
//  ArchiveView.swift
//  One - Günlük Mood
//

import SwiftUI
import CoreData

/// Container view that manages navigation between Month and Year archive views
struct ArchiveContainerView: View {
    @StateObject private var archiveStore: ArchiveStore
    @State private var showYearView = false

    init(context: NSManagedObjectContext) {
        _archiveStore = StateObject(wrappedValue: ArchiveStore(context: context))
    }

    var body: some View {
        ZStack {
            ONETokens.oneCream.ignoresSafeArea()

            if showYearView {
                YearArchiveView(
                    yearData: archiveStore.yearData,
                    onMonthTap: { month in
                        archiveStore.loadSpecificMonth(month: month)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showYearView = false
                        }
                    },
                    onAyTap: { showYearView = false }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                MonthArchiveView(
                    summary: archiveStore.currentMonth,
                    onDayTap: { _ in },
                    onYearTap:    { showYearView = true }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showYearView)
        .onAppear { archiveStore.loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .init("todaySongSaved"))) { _ in
            archiveStore.loadData()
        }
        // NavigationStack kaldırıldı — DayDetailView artık kullanılmıyor
        .environmentObject(archiveStore)
    }
}

// MARK: - Preview
#Preview {
    ArchiveContainerView(context: PersistenceController.preview.container.viewContext)
}
