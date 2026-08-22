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
    @State private var showStory = false
    @State private var posterLoadTimedOut = false
    /// Structured handle for the 10s poster-load watchdog.
    /// Ensures the sleeping Task is cancelled on view disappear,
    /// on successful poster load, and before a new timeout is spawned
    /// (retry path would otherwise stack concurrent watchdogs).
    @State private var timeoutTask: Task<Void, Never>? = nil
    @StateObject private var posterVM = MonthlySummaryViewModel(
        context: PersistenceController.shared.container.viewContext,
        year: Calendar.current.component(.year, from: Date()),
        month: Calendar.current.component(.month, from: Date())
    )

    var body: some View {
        ZStack(alignment: .topLeading) {
            V3Tokens.paper.ignoresSafeArea()

            if vm.isLoading {
                loadingView
            } else if vm.data.totalSongs == 0 {
                // A5 — Echo'da hiç data yok: zenginleştirme yerine ilk adımı öner
                echoEmptyState
            } else {
                // v3 spec: cover · mood map · en çok dinlenenler · sayısal · poster.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: V3Tokens.spacingXL) {
                        EchoCoverSection(
                            data: vm.data,
                            monthName: currentMonthName,
                            onStory: { showStory = true }
                        )

                        EchoMoodMapSection(data: vm.data)

                        EchoTopTracksSection(data: vm.data)

                        EchoStatsBreakdownSection(data: vm.data)

                        // Poster girişi — ayın renk mozaiği.
                        Button {
                            ONEHaptics.feelingSelected()
                            showPoster = true
                        } label: {
                            HStack {
                                Text(NSLocalizedString("year.poster", comment: ""))
                                    .bodyMDSemibold()
                                    .foregroundColor(V3Tokens.paper)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(V3Tokens.paper)
                            }
                            .padding(.horizontal, V3Tokens.spacingXL)
                            .padding(.vertical, 18)
                            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(V3Tokens.ink))
                        }
                        .buttonStyle(.onePressable)
                        .padding(.horizontal, V3Tokens.spacingXL)

                        Color.clear.frame(height: 100)
                    }
                    .padding(.top, V3Tokens.spacingXL2)
                }
            }

            // Ay hikayesi ve poster sunumları eskiden `EmptyView()` üzerine
            // bağlıydı. SwiftUI `EmptyView`'ı hiyerarşiden tamamen eliyor —
            // modifier hiç kurulmuyor, `showStory`/`showPoster` true olsa da
            // hiçbir şey açılmıyordu. Taşıyıcı gerçek bir view olmalı.
            Color.clear
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                // Ay hikayesi — 4 sayfa horizontal pager.
                .fullScreenCover(isPresented: $showStory) {
                    EchoMonthStoryView(
                        data: vm.data,
                        monthName: currentMonthName,
                        onClose: { showStory = false }
                    )
                }
                // Prototip 15 — aylık poster.
                .fullScreenCover(isPresented: $showPoster, onDismiss: {
                    posterLoadTimedOut = false
                }) {
                    if let data = posterVM.summaryData {
                        MonthPosterView(data: data, onBack: { showPoster = false })
                    } else if posterLoadTimedOut {
                        // 10sn içinde veri gelmediyse spinner'da takılmasın —
                        // net bir hata + geri dön akışı ver.
                        VStack(spacing: 14) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(V3Tokens.mutedText)
                            Text(NSLocalizedString("echo.posterFailed", comment: ""))
                                .bodyLG()
                                .foregroundColor(V3Tokens.ink)
                            Button {
                                posterLoadTimedOut = false
                                posterVM.load()
                                startPosterLoadTimeout()
                            } label: {
                                Text("Tekrar dene")
                                    .monoSM(tracking: 0.8)
                                    .foregroundColor(ONEBrand.bone)
                                    .padding(.horizontal, V3Tokens.spacingXL)
                                    .padding(.vertical, V3Tokens.spacingMD)
                                    .background(Capsule().fill(V3Tokens.ink))
                            }
                            Button("Kapat") { showPoster = false }
                                .foregroundColor(V3Tokens.mutedText)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(V3Tokens.paper.ignoresSafeArea())
                        // (v3: eski oneCream → bone)
                    } else {
                        ProgressView().task {
                            posterVM.load()
                            startPosterLoadTimeout()
                        }
                    }
                }

        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // Yankı bir katman: Profil'den modal olarak açılıyor. Kapatma
            // dairesel `xmark`, uygulamanın geri kalanıyla aynı. Eskiden üç
            // ayrı dil vardı — çağrı yerinde sistem toolbar'ının "Kapat"
            // metni, burada yüzen bir kapsül düğme ("Profile dön"), ve o
            // kapsülü aşmak için 90pt'lik elle yazılmış bir üst pay.
            if let onDismiss {
                V3TopBar(
                    leading: .close(onDismiss),
                    context: currentMonthName.uppercased(),
                    title: NSLocalizedString("nav.echo", comment: ""),
                    titleMode: .always,
                    progress: 1
                )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: ONEAnimation.durationLong).delay(0.15)) { appeared = true }
        }
        .onDisappear {
            // View kaybolurken uçuşta bir watchdog varsa iptal et; aksi
            // halde arka planda uyuyup 10sn sonra yok olmuş view'a yazar.
            timeoutTask?.cancel()
            timeoutTask = nil
        }
        .onChange(of: posterVM.summaryData == nil) { _, isNil in
            // Data geldiyse timeout artık gereksiz — iptal et.
            if !isNil {
                timeoutTask?.cancel()
                timeoutTask = nil
            }
        }
    }

    // MARK: — Empty state (A5)
    /// Echo'da hiç entry yok — kullanıcıya ilk somut next-action'ı öner.
    private var echoEmptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(V3Tokens.hairline, lineWidth: 1.2)
                    .frame(width: 78, height: 78)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(V3Tokens.mutedText)
            }

            VStack(spacing: V3Tokens.spacingSM) {
                Text(NSLocalizedString("echo.empty.title", comment: ""))
                    .displayMD()
                    .foregroundColor(V3Tokens.ink)
                    .multilineTextAlignment(.center)
                Text(NSLocalizedString("echo.empty.body", comment: ""))
                    .bodySM()
                    .foregroundColor(V3Tokens.mutedText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, V3Tokens.spacingXL3)
            }

            Button {
                if let onDismiss {
                    onDismiss()
                }
                NotificationCenter.default.post(name: .init("switchToTodayTab"), object: nil)
            } label: {
                Text(NSLocalizedString("echo.empty.cta", comment: ""))
                    .monoSM(tracking: 0.8)
                    .foregroundColor(ONEBrand.bone)
                    .padding(.horizontal, V3Tokens.spacingXL)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(V3Tokens.ink))
            }
            .padding(.top, 6)

            Spacer()
            Spacer().frame(height: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, V3Tokens.spacingXL2)
    }

    private var currentMonthName: String {
        let f = DateFormatter()
        f.locale = LanguageManager.shared.currentLocale
        f.setLocalizedDateFormatFromTemplate("MMMM")
        return f.string(from: Date())
    }

    /// 10sn içinde posterVM.summaryData dolmazsa error fallback tetiklenir.
    /// Handle saklanır ki `onDisappear`, başarılı load, ve tekrar-dene
    /// yolu eski watchdog'u iptal edip yenisini kurabilsin.
    private func startPosterLoadTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if showPoster && posterVM.summaryData == nil {
                    posterLoadTimedOut = true
                }
            }
        }
    }

    // MARK: — Loading
    private var loadingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: V3Tokens.radiusCard)
                    .fill(V3Tokens.hairline)
                    .frame(height: 88)
                    .padding(.horizontal, V3Tokens.spacingLG)
                    .padding(.vertical, V3Tokens.spacingSM)
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
