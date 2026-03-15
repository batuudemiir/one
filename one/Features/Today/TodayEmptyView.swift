//
//  TodayEmptyView.swift
//  One - Günlük Mood
//

import SwiftUI
import PhotosUI
import CoreData
import UIKit

// Step enum — tab bar gizleme kaldırıldı, sadece state takibi için
enum Step: Int, CaseIterable {
    case search   = 0
    case selecting = 1
}

struct TodayEmptyView: View {
    @ObservedObject var vm: TodayViewModel
    @Binding var currentStep: Step
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage(ONETokens.cityPreferenceKey) private var preferredCity: String = ONETokens.defaultCity
    @StateObject private var recommendationEngine: RecommendationEngine

    // Seçimler
    @State private var selectedSong: SongResult?    = nil
    @State private var selectedMood: MoodOption?    = nil
    @State private var selectedFeeling: FeelingType? = nil
    @State private var photoImage: UIImage?          = nil
    @State private var dailyNote: String             = ""
    @State private var sharePhoto                    = false

    // Arama
    @State private var searchText = ""

    // Şimdi çalıyor — Apple Music + Spotify birleşik
    @StateObject private var nowPlayingManager = NowPlayingManager.shared

    // Hangi bölümler açık
    @State private var showPhotoRow     = false
    @State private var showMoodSection  = false
    @State private var showFeelingSection = false
    @State private var showNoteSection  = false
    @State private var showSaveButton   = false

    // UI
    @State private var showCamera         = false
    @State private var showFullScreenPhoto = false
    @State private var photoZoomScale: CGFloat      = 1.0
    @State private var photoLastZoomScale: CGFloat  = 1.0
    @State private var photoDismissOffset: CGFloat  = 0
    @State private var photoPanOffset: CGSize       = .zero
    @State private var photoLastPanOffset: CGSize   = .zero
    @FocusState private var isNoteFieldFocused: Bool

    // Scroll proxy — mood/feeling action'larından erişmek için
    @State private var scrollProxy: ScrollViewProxy? = nil

    init(vm: TodayViewModel, currentStep: Binding<Step>) {
        self.vm = vm
        self._currentStep = currentStep
        let context = PersistenceController.shared.container.viewContext
        _recommendationEngine = StateObject(wrappedValue: RecommendationEngine(context: context))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Arka plan — mood tint
            ONETokens.oneCream
                .overlay(
                    Group {
                        if let mood = selectedMood {
                            mood.color.opacity(0.06).ignoresSafeArea()
                        }
                    }
                    .animation(.easeInOut(duration: 0.5), value: selectedMood?.key)
                )
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Selamlama
                        Text(timeGreetingText)
                            .bodyMD()
                            .foregroundColor(ONETokens.oneAsh)
                            .padding(.bottom, 16)

                        // Şimdi çalıyor banner'ı (Apple Music veya Spotify, şarkı seçilmemişse)
                        if selectedSong == nil,
                           let track = nowPlayingManager.currentTrack {
                            nowPlayingBanner(track: track)
                                .padding(.bottom, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Arama
                        songSearchSection

                        if selectedSong != nil {

                            // ── Fotoğraf ────────────────────────────
                            if showPhotoRow {
                                sectionDivider
                                photoRow
                                    .padding(.top, 20)
                                    .id("photoRow")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                                if let photo = photoImage {
                                    photoPreview(photo)
                                        .padding(.top, 12)
                                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                                }

                                // Fotoğrafsız devam et — mood'a geç
                                if !showMoodSection {
                                    continueButton(label: "Fotoğrafsız devam et") {
                                        reveal("moodSection", proxy: proxy) {
                                            showMoodSection = true
                                        }
                                    }
                                    .padding(.top, 20)
                                    .id("photoCTA")
                                }
                            }

                            // ── Mood ─────────────────────────────────
                            if showMoodSection {
                                sectionDivider
                                moodSection
                                    .padding(.top, 20)
                                    .id("moodSection")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                            }

                            // ── Feeling ──────────────────────────────
                            if showFeelingSection {
                                sectionDivider
                                feelingSection
                                    .padding(.top, 20)
                                    .id("feelingSection")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            // ── Not ───────────────────────────────────
                            if showNoteSection {
                                sectionDivider
                                noteField
                                    .padding(.top, 20)
                                    .id("noteSection")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                                if !showSaveButton {
                                    continueButton(label: "Hazır") {
                                        withAnimation(ONEAnimation.panelSpring) {
                                            showSaveButton = true
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            withAnimation { proxy.scrollTo("saveCTA", anchor: .bottom) }
                                        }
                                    }
                                    .padding(.top, 20)
                                    .id("noteCTA")
                                }
                            }

                            // ── Kaydet ────────────────────────────────
                            if showSaveButton {
                                saveButton
                                    .padding(.top, 24)
                                    .id("saveCTA")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                        }

                        // Öneriler
                        if selectedSong == nil && searchText.isEmpty {
                            RecommendationsSection(
                                engine: recommendationEngine,
                                onSelectSong: { rec in
                                    let id  = UUID(uuidString: rec.id) ?? UUID()
                                    let url = rec.spotifyURL.flatMap { URL(string: $0) }
                                    selectSong(SongResult(
                                        id: id,
                                        name: rec.name,
                                        artist: rec.artist,
                                        genre: rec.genre ?? "Müzik",
                                        coverURL: rec.coverURL,
                                        spotifyURL: url,
                                        artworkURLString: rec.coverURL?.absoluteString
                                    ))
                                }
                            )
                        }

                        Color.clear.frame(height: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 52)
                    .padding(.bottom, 16)
                    .onAppear { scrollProxy = proxy }
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .animation(ONEAnimation.panelSpring, value: showPhotoRow)
        .animation(ONEAnimation.panelSpring, value: showMoodSection)
        .animation(ONEAnimation.panelSpring, value: showFeelingSection)
        .animation(ONEAnimation.panelSpring, value: showNoteSection)
        .animation(ONEAnimation.panelSpring, value: showSaveButton)
        .animation(ONEAnimation.panelSpring, value: selectedSong != nil)
        .onChange(of: photoImage) { _, newPhoto in
            guard newPhoto != nil, !showMoodSection, let proxy = scrollProxy else { return }
            reveal("moodSection", proxy: proxy) { showMoodSection = true }
        }
        .sheet(isPresented: $showCamera) { CameraView(image: $photoImage) }
        .fullScreenCover(isPresented: $showFullScreenPhoto) { photoFullScreenView }
        .task { await recommendationEngine.fetchRecommendations() }
        .task {
            // Apple Music + Spotify now playing polling başlat
            nowPlayingManager.startPolling()
        }
        .onDisappear {
            nowPlayingManager.stopPolling()
        }
    }

    // MARK: - Section Divider

    var sectionDivider: some View {
        Rectangle()
            .fill(ONETokens.oneSilver)
            .frame(height: 1)
            .padding(.top, 24)
    }

    // MARK: - Şimdi Çalıyor Banner'ı

    func nowPlayingBanner(track: NowPlayingTrack) -> some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            let song = SongResult(
                id: UUID(),
                name: track.name,
                artist: track.artist,
                genre: "Müzik",
                coverURL: track.artworkURL,
                spotifyURL: track.spotifyURL,
                artworkURLString: track.artworkURL?.absoluteString
            )
            selectSong(song)
        }) {
            HStack(spacing: 12) {
                // Albüm kapağı
                Group {
                    if let url = track.artworkURL {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            ONETokens.oneSilver
                        }
                    } else {
                        ONETokens.oneSilver
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Şarkı bilgisi
                VStack(alignment: .leading, spacing: 3) {
                    // Platform göstergesi
                    HStack(spacing: 5) {
                        Circle()
                            .fill(track.source == .spotify ? ONETokens.spotifyGreen : ONETokens.appleMusicRed)
                            .frame(width: 6, height: 6)
                        Text(track.source == .spotify ? "Spotify'da çalıyor" : "Apple Music'te çalıyor")
                            .monoLabel(tracking: 0.8)
                            .foregroundColor(track.source == .spotify ? ONETokens.spotifyGreen : ONETokens.appleMusicRed)
                    }
                    Text(track.name)
                        .bodyMD()
                        .foregroundColor(ONETokens.oneShadow)
                        .lineLimit(1)
                    Text(track.artist)
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneMist)
                        .lineLimit(1)
                }

                Spacer()

                // Seç butonu
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ONETokens.oneShadow)
                    Text("seç")
                        .monoLabel(tracking: 0.5)
                        .foregroundColor(ONETokens.oneMist)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Şarkı Arama

    var songSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if selectedSong == nil {
                Text("Bugünün şarkısını seç")
                    .displayLG()
                    .foregroundColor(ONETokens.oneShadow)
                    .lineSpacing(2)
                    .padding(.bottom, 2)

                Text("Mood'unu ve gününü buradan başlat.")
                    .monoBase(tracking: 0.2)
                    .foregroundColor(ONETokens.oneAsh)
                    .padding(.bottom, 12)

                // Arama kutusu
                HStack(spacing: 10) {
                    if vm.isSearching {
                        ProgressView().scaleEffect(0.7).frame(width: 13, height: 13)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(ONETokens.oneMist)
                    }
                    TextField("Şarkı veya sanatçı ara", text: $searchText)
                        .monoSM(tracking: 0)
                        .foregroundColor(ONETokens.oneShadow)
                        .onChange(of: searchText) { _, v in vm.search(v) }
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; vm.searchResults = [] }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ONETokens.oneMist)
                                .font(.system(size: 13))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 13).fill(ONETokens.oneSilver))

                // Son sanatçılar
                if searchText.isEmpty && !vm.recentArtists.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.recentArtists, id: \.self) { artist in
                                Button(action: { searchText = artist; vm.search(artist) }) {
                                    Text(artist)
                                        .monoSM(tracking: 0.6)
                                        .foregroundColor(ONETokens.oneAsh)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Capsule().stroke(ONETokens.oneCreamMid, lineWidth: 1))
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // Sonuçlar
                if !vm.searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(vm.searchResults) { song in
                            Button(action: { selectSong(song) }) {
                                HStack(spacing: 12) {
                                    Group {
                                        if let url = song.coverURL {
                                            AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                                placeholder: { ONETokens.oneSilver }
                                        } else { ONETokens.oneSilver }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(song.name).bodyMD().foregroundColor(ONETokens.oneShadow).lineLimit(1)
                                        Text(song.artist).monoSM(tracking: 0).foregroundColor(ONETokens.oneMist)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider().background(ONETokens.oneSilver)
                        }
                    }
                    .padding(.top, 4)
                }

                if let err = vm.searchError {
                    Text(err).monoSM(tracking: 0).foregroundColor(ONETokens.oneRed.opacity(0.7)).padding(.top, 6)
                } else if !searchText.isEmpty && !vm.isSearching && vm.searchResults.isEmpty {
                    Text("Sonuç bulunamadı").monoSM(tracking: 0).foregroundColor(ONETokens.oneCreamLow).padding(.top, 6)
                }
            }

            // Seçilen şarkı kartı
            if let song = selectedSong {
                selectedSongCard(song)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
    }

    // MARK: - Seçilen Şarkı Kartı

    func selectedSongCard(_ song: SongResult) -> some View {
        HStack(spacing: 14) {
            Group {
                if let url = song.coverURL {
                    AsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { ONETokens.oneSilver }
                } else { ONETokens.oneSilver }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(song.name).displaySM().foregroundColor(ONETokens.oneShadow).lineLimit(1)
                Text(song.artist).monoSM(tracking: 0).foregroundColor(ONETokens.oneMist)
            }
            Spacer()

            Button(action: { resetAll() }) {
                Text("değiştir")
                    .monoSM(tracking: 1.0)
                    .foregroundColor(ONETokens.oneCreamLow)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(ONETokens.oneSilver))
    }

    // MARK: - Fotoğraf Satırı

    var photoRow: some View {
        Button(action: { ONEHaptics.feelingSelected(); showCamera = true }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(photoImage != nil ? ONETokens.oneGreen.opacity(0.15) : ONETokens.oneCreamMid)
                        .frame(width: 40, height: 40)
                    Image(systemName: photoImage != nil ? "checkmark" : "camera")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(photoImage != nil ? ONETokens.oneGreen : ONETokens.oneAsh)
                }
                Text(photoImage != nil ? "Fotoğraf eklendi" : "Fotoğraf ekle")
                    .bodyMD().foregroundColor(ONETokens.oneShadow)
                Spacer()
                if photoImage == nil {
                    Text("opsiyonel").monoSM(tracking: 0.5).foregroundColor(ONETokens.oneMist)
                }
                if photoImage != nil {
                    Button(action: { withAnimation(ONEAnimation.micro) { photoImage = nil } }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundColor(ONETokens.oneMist)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ONETokens.oneSilver)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(photoImage != nil ? ONETokens.oneGreen.opacity(0.4) : Color.clear, lineWidth: 1))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func photoPreview(_ photo: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity).frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture { showFullScreenPhoto = true }
            Button(action: { showCamera = true }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                    .padding(9).background(Circle().fill(Color.black.opacity(0.45)))
            }
            .padding(10)
        }
    }

    // MARK: - Mood Seçimi

    var moodSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("nasıl hissediyorsun?")
                .bodySM().foregroundColor(ONETokens.oneAsh)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                ForEach(MoodOption.all) { mood in
                    Button(action: {
                        ONEHaptics.moodSelected()
                        withAnimation(ONEAnimation.micro) { selectedMood = mood }
                        if !showFeelingSection, let proxy = scrollProxy {
                            reveal("feelingSection", proxy: proxy) { showFeelingSection = true }
                        }
                    }) {
                        VStack(spacing: 7) {
                            Circle()
                                .fill(mood.color)
                                .frame(width: 46, height: 46)
                                .overlay(Circle()
                                    .stroke(ONETokens.oneShadow, lineWidth: selectedMood?.key == mood.key ? 2.5 : 0)
                                    .padding(-3))
                                .scaleEffect(selectedMood?.key == mood.key ? 1.1 : 1.0)
                                .animation(ONEAnimation.micro, value: selectedMood?.key)
                            Text(mood.label.uppercased())
                                .monoLabel(tracking: 0.6)
                                .foregroundColor(selectedMood?.key == mood.key ? ONETokens.oneGraphite : ONETokens.oneMist)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Feeling Seçimi
    // 4×2 grid — minimalist metin pill'leri, mood rengini miras alır.

    var feelingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("bu şarkı sende ne bıraktı?")
                .bodySM()
                .foregroundColor(ONETokens.oneAsh)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                spacing: 8
            ) {
                ForEach(FeelingOption.all) { feel in
                    let isSelected = selectedFeeling == feel.type
                    let accent = selectedMood?.color ?? ONETokens.oneCharcoal

                    Button(action: {
                        ONEHaptics.feelingSelected()
                        withAnimation(ONEAnimation.micro) { selectedFeeling = feel.type }
                        if !showNoteSection, let proxy = scrollProxy {
                            reveal("noteSection", proxy: proxy) { showNoteSection = true }
                        }
                    }) {
                        Text(feel.label)
                            .monoLabel(tracking: 0.3)
                            .foregroundColor(isSelected ? accent : ONETokens.oneCharcoal)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                                    .fill(isSelected
                                          ? accent.opacity(0.10)
                                          : ONETokens.oneSilver.opacity(0.55))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                                            .stroke(isSelected ? accent.opacity(0.30) : Color.clear,
                                                    lineWidth: 1)
                                    )
                            )
                            .scaleEffect(isSelected ? 1.04 : 1.0)
                            .animation(ONEAnimation.micro, value: selectedFeeling)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Not Alanı

    var noteField: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("bir not bırak")
                .bodySM().foregroundColor(ONETokens.oneAsh)

            HStack(spacing: 12) {
                TextField("Bugün ne hissediyorsun? (opsiyonel)", text: $dailyNote)
                    .monoSM(tracking: 0).foregroundColor(ONETokens.oneShadow)
                    .submitLabel(.done).focused($isNoteFieldFocused)
                    .onSubmit { isNoteFieldFocused = false }
                if !dailyNote.isEmpty {
                    Button(action: { dailyNote = "" }) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(ONETokens.oneMist)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                    .fill(isNoteFieldFocused ? Color.white : ONETokens.oneSilver)
                    .shadow(color: isNoteFieldFocused ? Color.black.opacity(0.06) : Color.clear, radius: 8, x: 0, y: 3)
            )
            .animation(ONEAnimation.micro, value: isNoteFieldFocused)
        }
    }

    // MARK: - Devam Et Butonu

    func continueButton(label: String = "Devam et", enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { action() } }) {
            HStack(spacing: 6) {
                Text(label)
                    .monoSM(tracking: 1.2)
                    .foregroundColor(enabled ? ONETokens.oneShadow : ONETokens.oneMist)
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(enabled ? ONETokens.oneShadow : ONETokens.oneMist)
            }
            .padding(.horizontal, 18).padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(enabled ? ONETokens.oneSilver : ONETokens.oneCreamMid)
                    .overlay(Capsule().stroke(enabled ? ONETokens.oneCreamMid : Color.clear, lineWidth: 1))
            )
        }
        .disabled(!enabled)
        .animation(ONEAnimation.micro, value: enabled)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Kaydet Butonu

    var saveButton: some View {
        VStack(spacing: 14) {
            // Mood + feeling özet pill
            if let mood = selectedMood, let feeling = selectedFeeling {
                HStack(spacing: 8) {
                    Circle().fill(mood.color).frame(width: 10, height: 10)
                    Text("\(mood.label)  ·  \(FeelingOption.all.first { $0.type == feeling }?.label ?? "")")
                        .monoSM(tracking: 0.8).foregroundColor(ONETokens.oneAsh)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(ONETokens.oneSilver))
            }

            // Çevre paylaşım toggle
            if photoImage != nil {
                HStack {
                    Text("Fotoğrafı çevrede paylaş")
                        .monoSM(tracking: 0.6).foregroundColor(ONETokens.oneMist)
                    Spacer()
                    Toggle("", isOn: $sharePhoto).toggleStyle(ONEToggleStyle())
                }
                .padding(.horizontal, 4)
            }

            Text("Hisset. Keşfet. Paylaş.")
                .monoSM(tracking: 1.2)
                .foregroundColor(ONETokens.oneMist)

            // Ana CTA
            Button(action: {
                guard let song = selectedSong,
                      let mood = selectedMood,
                      let feeling = selectedFeeling else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                vm.saveEntry(song: song, mood: mood, feeling: feeling,
                             photo: photoImage, note: dailyNote, sharePhoto: sharePhoto)
            }) {
                Text("Bugünün şarkısı bu")
                    .displayXS()
                    .foregroundColor(ONETokens.oneCream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedMood?.color ?? ONETokens.oneShadow)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .animation(ONEAnimation.micro, value: selectedMood?.key)

            // Şarkıyı değiştir
            Button(action: { resetAll() }) {
                Text("şarkıyı değiştir")
                    .monoSM(tracking: 0.8).foregroundColor(ONETokens.oneMist)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Tam Ekran Fotoğraf

    var photoFullScreenView: some View {
        let isZoomed = photoZoomScale > 1.01
        return GeometryReader { geo in ZStack {
            Color.black
                .opacity(1.0 - Double(abs(photoDismissOffset)) / 400)
                .ignoresSafeArea()

            if let photo = photoImage {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(photoZoomScale)
                    .offset(
                        x: isZoomed ? photoPanOffset.width  : 0,
                        y: isZoomed ? photoPanOffset.height : photoDismissOffset
                    )
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { v in
                                    photoZoomScale = min(max(photoLastZoomScale * v, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    photoLastZoomScale = photoZoomScale
                                    if photoZoomScale <= 1.0 {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            photoZoomScale = 1.0
                                            photoLastZoomScale = 1.0
                                            photoPanOffset = .zero
                                            photoLastPanOffset = .zero
                                        }
                                    }
                                },
                            DragGesture()
                                .onChanged { val in
                                    if photoZoomScale > 1.01 {
                                        // Zoom'dayken görüntüyü kaydır — ekran sınırları aşılmaz
                                        let maxX = (photoZoomScale - 1) * geo.size.width  / 2
                                        let maxY = (photoZoomScale - 1) * geo.size.height / 2
                                        photoPanOffset = CGSize(
                                            width:  min(max(photoLastPanOffset.width  + val.translation.width,  -maxX), maxX),
                                            height: min(max(photoLastPanOffset.height + val.translation.height, -maxY), maxY)
                                        )
                                    } else {
                                        // Normal modda: aşağı sürükle → kapat
                                        let dy = val.translation.height
                                        if dy > 0 { photoDismissOffset = dy }
                                    }
                                }
                                .onEnded { val in
                                    if photoZoomScale > 1.01 {
                                        photoLastPanOffset = photoPanOffset
                                    } else if val.translation.height > 120 {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        showFullScreenPhoto = false
                                        photoZoomScale = 1.0
                                        photoLastZoomScale = 1.0
                                        photoDismissOffset = 0
                                        photoPanOffset = .zero
                                        photoLastPanOffset = .zero
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            photoDismissOffset = 0
                                        }
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if isZoomed {
                                photoZoomScale = 1.0
                                photoLastZoomScale = 1.0
                                photoPanOffset = .zero
                                photoLastPanOffset = .zero
                            } else {
                                photoZoomScale = 2.5
                                photoLastZoomScale = 2.5
                            }
                        }
                    }
            }

            // Kapatma butonu + kaydır ipucu — zoom'dayken sabit, değilse fotoğrafla kayar
            VStack {
                HStack {
                    Button(action: {
                        showFullScreenPhoto = false
                        photoDismissOffset = 0
                        photoZoomScale = 1.0
                        photoLastZoomScale = 1.0
                        photoPanOffset = .zero
                        photoLastPanOffset = .zero
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 20).padding(.top, 16)
                    Spacer()
                }
                Spacer()
                // Aşağı kaydır ipucu — zoom modunda gizle
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white.opacity(isZoomed ? 0 : 0.3))
                    .padding(.bottom, 24)
                    .animation(ONEAnimation.micro, value: isZoomed)
            }
            .offset(y: isZoomed ? 0 : photoDismissOffset)
        } }
    }

    // MARK: - Helpers

    private var timeGreetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<10:  return "Gün henüz başlıyor."
        case 10..<14: return "Günün ortasındasın."
        case 14..<19: return "Öğleden sonra."
        case 19..<23: return "Gün bitmek üzere."
        default:      return "Gece."
        }
    }

    /// Bölümü aç ve scroll yap
    private func reveal(_ id: String, proxy: ScrollViewProxy, action: @escaping () -> Void) {
        withAnimation(ONEAnimation.panelSpring) { action() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }

    private func selectSong(_ song: SongResult) {
        ONEHaptics.feelingSelected()
        withAnimation(ONEAnimation.panelSpring) {
            selectedSong = song
            searchText   = ""
            vm.searchResults = []
            currentStep  = .selecting
        }
        withAnimation(ONEAnimation.panelSpring.delay(0.2)) {
            showPhotoRow = true
        }
    }

    private func resetAll() {
        ONEHaptics.moodSelected()
        withAnimation(ONEAnimation.panelSpring) {
            selectedSong    = nil
            selectedMood    = nil
            selectedFeeling = nil
            photoImage      = nil
            dailyNote       = ""
            sharePhoto      = false
            searchText      = ""
            showPhotoRow    = false
            showMoodSection    = false
            showFeelingSection = false
            showNoteSection    = false
            showSaveButton     = false
            currentStep     = .search
            photoZoomScale     = 1.0
            photoLastZoomScale = 1.0
            photoDismissOffset = 0
            photoPanOffset     = .zero
            photoLastPanOffset = .zero
        }
    }
}

// MARK: - ScaleButtonStyle

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? ONEAnimation.buttonPressScale : 1)
            .animation(
                configuration.isPressed ? ONEAnimation.buttonPressAnimation : ONEAnimation.buttonReleaseAnimation,
                value: configuration.isPressed
            )
    }
}
