//
//  EchoView.swift
//  One - Günlük Mood
//
//  UX redesign: kart tabanlı düzen, net tipografi hiyerarşisi,
//  okunabilir font boyutları, sosyal ürün dili tutarlılığı.
//

import SwiftUI
import CoreData

struct EchoView: View {
    @StateObject private var vm: EchoViewModel
    @State private var appeared = false
    private let context: NSManagedObjectContext
    var onDismiss: (() -> Void)? = nil

    init(context: NSManagedObjectContext, onDismiss: (() -> Void)? = nil) {
        self.context = context
        self.onDismiss = onDismiss
        _vm = StateObject(wrappedValue: EchoViewModel(context: context))
    }

    @State private var showPoster = false
    @StateObject private var posterVM = MonthlySummaryViewModel(
        context: PersistenceController.shared.container.viewContext,
        year: Calendar.current.component(.year, from: Date()),
        month: Calendar.current.component(.month, from: Date())
    )

    var body: some View {
        ZStack(alignment: .topLeading) {
            ONETokens.oneCream.ignoresSafeArea()

            if vm.isLoading {
                loadingView
            } else if vm.data.totalSongs == 0 {
                // A5 — Echo'da hiç data yok: zenginleştirme yerine ilk adımı öner
                echoEmptyState
            } else {
                // Prototip: yedi bölümlü pano değil, iki içgörü kartı.
                // Eski bölümler silindi.
                ScrollView(showsIndicators: false) {
                    EchoOverviewView(data: vm.data, onPoster: { showPoster = true })
                        .padding(.top, onDismiss != nil ? 90 : ONETokens.spacingXL3)
                }
            }

            // Prototip 15 — aylık poster.
            EmptyView()
                .fullScreenCover(isPresented: $showPoster) {
                    if let data = posterVM.summaryData {
                        MonthPosterView(data: data, onBack: { showPoster = false })
                    } else {
                        ProgressView().task { posterVM.load() }
                    }
                }

            // Fixed back button (outside ScrollView)
            if let onDismiss {
                Button(action: onDismiss) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text(NSLocalizedString("echo.backToProfile", comment: ""))
                            .bodySMMedium()
                    }
                    .foregroundColor(ONETokens.oneInk)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(ONETokens.onePaper.opacity(0.9))
                            .overlay(Capsule().stroke(ONETokens.oneSilver, lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
                    )
                }
                .padding(.top, 54)
                .padding(.leading, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.15)) { appeared = true }
        }
    }

    // MARK: — Empty state (A5)
    /// Echo'da hiç entry yok — kullanıcıya ilk somut next-action'ı öner.
    private var echoEmptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(ONETokens.oneSilver, lineWidth: 1.2)
                    .frame(width: 78, height: 78)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(ONETokens.oneAsh)
            }

            VStack(spacing: 8) {
                Text(NSLocalizedString("echo.empty.title", comment: ""))
                    .displayMD()
                    .foregroundColor(ONETokens.oneInk)
                    .multilineTextAlignment(.center)
                Text(NSLocalizedString("echo.empty.body", comment: ""))
                    .bodySM()
                    .foregroundColor(ONETokens.oneAsh)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }

            Button {
                if let onDismiss {
                    onDismiss()
                }
                NotificationCenter.default.post(name: .init("switchToTodayTab"), object: nil)
            } label: {
                Text(NSLocalizedString("echo.empty.cta", comment: ""))
                    .monoSM(tracking: 0.8)
                    .foregroundColor(ONETokens.oneCream)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(ONETokens.oneInk))
            }
            .padding(.top, 6)

            Spacer()
            Spacer().frame(height: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    // MARK: — Loading
    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                    .fill(ONETokens.oneSilver)
                    .frame(height: 88)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .shimmeringCircle()
            }
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EchoView(context: PersistenceController.preview.container.viewContext)
}
