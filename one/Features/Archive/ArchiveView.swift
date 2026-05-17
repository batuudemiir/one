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

            if archiveStore.isLoading && archiveStore.yearData.isEmpty {
                ArchiveSkeletonView()
            } else {
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
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                } else {
                    MonthArchiveView(
                        summary: archiveStore.currentMonth,
                        onDayTap: { _ in },
                        onYearTap: { showYearView = true }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showYearView)
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
