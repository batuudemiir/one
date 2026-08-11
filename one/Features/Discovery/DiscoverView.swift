import SwiftUI
import CoreData

struct KesfetFooterView: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("ONE")
                .font(V3Typography.sans(11, weight: .semibold))
                .tracking(2.5)
                .foregroundColor(V3Tokens.ink.opacity(0.35))
            Text("Hisset. Keşfet. Paylaş.")
                .font(V3Typography.sans(13, weight: .regular))
                .foregroundColor(V3Tokens.ink.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}

struct SectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(ONETypography.displayLgAlt)
            .foregroundColor(V3Tokens.ink)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
}

struct DiscoverView: View {
    @StateObject private var kesfetVM = KesfetViewModel()
    @StateObject private var discoverVM: DiscoverViewModel
    @AppStorage(ONETokens.cityPreferenceKey) private var preferredCity: String = ONETokens.defaultCity
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        _discoverVM = StateObject(wrappedValue: DiscoverViewModel(context: context))
    }

    var body: some View {
        // Prototip 23 — eski akış motoru gövdesi (`legacyBody`) dosyada
        // duruyor ama çizilmiyor; keşfet artık editoryal kart listesi.
        DiscoverScreen(vm: discoverVM, onBack: {
            NotificationCenter.default.post(name: .init("switchToCircleTab"), object: nil)
        })
        .task { await discoverVM.refresh() }
    }

    private var legacyBody: some View {
        ZStack {
            LinearGradient(
                colors: [kesfetVM.mood?.color.opacity(0.12) ?? ONEBrand.bone, ONEBrand.bone],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: kesfetVM.selectedMoodId)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    KesfetTopBar(vm: kesfetVM)
                    
                    if kesfetVM.selectedMoodId != nil {
                        MoodHeroView(vm: kesfetVM)
                    } else {
                        VStack(spacing: 8) {
                            Text("Nasıl hissediyorsun?")
                                .font(ONETypography.displayMD)
                                .foregroundColor(V3Tokens.ink)
                            Text("Bugün hissettiğin bir mood seç. Sana yakın müzik ve etkinlikler seni bekliyor.")
                                .font(ONETypography.bodySM)
                                .foregroundColor(V3Tokens.mutedText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button {
                                NotificationCenter.default.post(name: NSNotification.Name("switchToTodayTab"), object: nil)
                            } label: {
                                Text("Bugünü kaydet")
                                    .font(ONETypography.monoBase)
                                    .foregroundColor(ONEBrand.bone)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(V3Tokens.ink)
                                    .clipShape(Capsule())
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 32)
                    }
                    
                    if discoverVM.isLoadingEvents || discoverVM.isLoadingMusic {
                        ProgressView()
                            .padding(.top, 40)
                    } else if kesfetVM.selectedMoodId != nil &&
                              discoverVM.musicRecommendations.isEmpty &&
                              discoverVM.recommendationSections.isEmpty &&
                              discoverVM.socialMusicRecommendations.isEmpty {
                        // Mood seçili ama içerik yok — empty state
                        VStack(spacing: 10) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 36, weight: .ultraLight))
                                .foregroundStyle(V3Tokens.mutedText)
                            Text("Bu his için henüz öneri yok.")
                                .font(ONETypography.bodySMMedium)
                                .foregroundStyle(V3Tokens.mutedText)
                            Text("Yakında burada olacak.")
                                .font(ONETypography.bodyXS)
                                .foregroundStyle(V3Tokens.faintText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    } else {
                        // MARK: - Müzik Önerileri
                        if !discoverVM.musicRecommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeaderView(title: "Senin İçin")
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(discoverVM.musicRecommendations) { rec in
                                            RecommendationCardView(
                                                recommendation: rec,
                                                onTap: {
                                                    if let urlString = rec.spotifyURL, let url = URL(string: urlString) {
                                                        UIApplication.shared.open(url)
                                                    }
                                                },
                                                onDismiss: {
                                                    discoverVM.recommendationEngine.dismissRecommendation(rec)
                                                }
                                            )
                                            .frame(width: 140)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                            .padding(.bottom, 16)
                        }

                        // MARK: - Etkinlik Bölümleri
                        ForEach(discoverVM.recommendationSections) { section in
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeaderView(title: section.title)
                                
                                ForEach(section.items) { event in
                                    DiscoverEventCard(event: event, moodColor: kesfetVM.mood?.color ?? ONEBrand.kor)
                                        .padding(.horizontal, 24)
                                }
                            }
                        }



                        // MARK: - Çevrendeki Ritim (Sosyal Keşif)
                        if !discoverVM.socialMusicRecommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeaderView(title: "Çevrendeki Ritim")
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(discoverVM.socialMusicRecommendations) { rec in
                                            RecommendationCardView(
                                                recommendation: rec,
                                                onTap: {
                                                    if let urlString = rec.spotifyURL, let url = URL(string: urlString) {
                                                        UIApplication.shared.open(url)
                                                    }
                                                },
                                                onDismiss: {
                                                    // No op for social recs for now
                                                }
                                            )
                                            .frame(width: 140)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                            .padding(.bottom, 16)
                        }

                        // MARK: - Genel Müzik Önerileri (Her Zaman Görünür)
                        if !discoverVM.generalMusicRecommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeaderView(title: "Günün Öne Çıkanları")
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(discoverVM.generalMusicRecommendations) { rec in
                                            RecommendationCardView(
                                                recommendation: rec,
                                                onTap: {
                                                    if let urlString = rec.spotifyURL, let url = URL(string: urlString) {
                                                        UIApplication.shared.open(url)
                                                    }
                                                },
                                                onDismiss: {
                                                    discoverVM.recommendationEngine.dismissRecommendation(rec)
                                                }
                                            )
                                            .frame(width: 140)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                            .padding(.bottom, 16)
                        }

                        // MARK: - Genel Etkinlikler (Her Zaman Görünür)
                        ForEach(discoverVM.generalSections) { section in
                            VStack(alignment: .leading, spacing: 16) {
                                SectionHeaderView(title: section.title)
                                
                                ForEach(section.items) { event in
                                    // Saturated ONE brand color since no mood is tied
                                    DiscoverEventCard(event: event, moodColor: Color(hex: "#4BBFA8"))
                                        .padding(.horizontal, 24)
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                    KesfetFooterView()
                }
                .padding(.bottom, 120)
            }
            .sheet(item: $kesfetVM.venueSheetPayload) { payload in
                VenueDetailSheet(payload: payload)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            AppAnalytics.shared.track(.discoverOpened)
            discoverVM.loadTodayEntry()
            if let mood = discoverVM.todayEntry?.normalizedMoodLabel {
                kesfetVM.configure(from: mood)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("todaySongSaved"))) { _ in
            discoverVM.loadTodayEntry()
            if let mood = discoverVM.todayEntry?.normalizedMoodLabel {
                kesfetVM.configure(from: mood)
            }
        }
        .onChange(of: discoverVM.todayEntry?.normalizedMoodLabel) { _, new in
            if let new { kesfetVM.configure(from: new) }
        }
        .onChange(of: kesfetVM.selectedMoodId) { _, newId in
            Task {
                await discoverVM.fetchContentFor(moodId: newId, kesfetMood: kesfetVM.mood)
            }
        }
        .onChange(of: preferredCity) { _, newCity in
            discoverVM.preferredCity = newCity
            Task {
                await discoverVM.fetchContentFor(moodId: kesfetVM.selectedMoodId, kesfetMood: kesfetVM.mood)
            }
        }
        .task { 
            await discoverVM.fetchContentFor(moodId: kesfetVM.selectedMoodId, kesfetMood: kesfetVM.mood) 
        }
    }
}
