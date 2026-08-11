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
    @Environment(\.managedObjectContext) var viewContext
    @StateObject var recommendationEngine: RecommendationEngine

    // Seçimler
    @State var selectedSong: SongResult?    = nil
    @State var selectedMood: MoodOption?    = nil
    @State var photoImage: UIImage?          = nil
    @State var dailyNote: String             = ""
    @State var sharePhoto                    = false

    // Arama
    @State var searchText = ""

    // Şimdi çalıyor — Apple Music + Spotify birleşik
    @StateObject var nowPlayingManager = NowPlayingManager.shared

    // Hangi bölümler açık
    @State var showPhotoRow     = false
    @State var showMoodSection  = false
    @State var showNoteSection  = false
    @State var showSaveButton   = false

    // UI
    @State var showCamera         = false
    @State var showFullScreenPhoto = false
    @State var photoZoomScale: CGFloat      = 1.0
    @State var photoLastZoomScale: CGFloat  = 1.0
    @State var photoDismissOffset: CGFloat  = 0
    @State var photoPanOffset: CGSize       = .zero
    @State var photoLastPanOffset: CGSize   = .zero
    @FocusState var isNoteFieldFocused: Bool

    // Scroll proxy — mood/feeling action'larından erişmek için
    @State var scrollProxy: ScrollViewProxy? = nil

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
            ONEBrand.bone
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

                        ZStack(alignment: .trailing) {
                            Text("ONE")
                                .font(ONETypography.displayXL)
                                .foregroundColor(V3Tokens.ink)
                                .frame(maxWidth: .infinity)

                            if vm.streakDays >= 1 {
                                let isMilestone = [3, 7, 14, 30, 50, 100, 200, 365].contains(vm.streakDays)
                                Text("🔥 \(vm.streakDays)")
                                    .monoSM(tracking: 1)
                                    .foregroundColor(V3Tokens.ink)
                                    .contentTransition(.numericText())
                                    .animation(.snappy, value: vm.streakDays)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(V3Tokens.surface)
                                            .overlay(Capsule().stroke(isMilestone ? ONEBrand.kor.opacity(0.5) : V3Tokens.hairline, lineWidth: isMilestone ? 1.5 : 1))
                                    )
                            }
                        }
                        .padding(.bottom, 10)

                        // "Bu gün geçen yıl" hafıza kartı
                        if let lastYear = vm.lastYearEntry, selectedSong == nil {
                            lastYearMemoryCard(lastYear)
                                .padding(.bottom, 20)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Şimdi çalıyor banner'ı (Apple Music veya Spotify, şarkı seçilmemişse)
                        if selectedSong == nil,
                           let track = nowPlayingManager.currentTrack {
                            nowPlayingBanner(track: track)
                                .padding(.bottom, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Arama
                        songSearchSection
                            .padding(.top, 24)

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
                                    continueButton(label: NSLocalizedString("today.continueWithoutPhoto", comment: "")) {
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

                            // ── Not ───────────────────────────────────
                            if showNoteSection {
                                sectionDivider
                                noteField
                                    .padding(.top, 20)
                                    .id("noteSection")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                                if !showSaveButton {
                                    continueButton(label: NSLocalizedString("today.done", comment: "")) {
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

                        // Öneriler — şarkı seçilmediği sürece her zaman göster
                        if selectedSong == nil {
                            RecommendationsSection(
                                engine: recommendationEngine,
                                onSelectSong: { rec in
                                    let id  = UUID(uuidString: rec.id) ?? UUID()
                                    let url = rec.spotifyURL.flatMap { URL(string: $0) }
                                    selectSong(SongResult(
                                        id: id,
                                        name: rec.name,
                                        artist: rec.artist,
                                        genre: rec.genre ?? NSLocalizedString("genre.music", comment: ""),
                                        coverURL: rec.coverURL,
                                        spotifyURL: url,
                                        artworkURLString: rec.coverURL?.absoluteString
                                    ))
                                }
                            )
                        }

                        // #10 — Pas butonu: şarkı seçilmediğinde, sayfanın en altında
                        if selectedSong == nil {
                            passButton
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                        }

                        Color.clear.frame(height: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 52)
                    .padding(.bottom, 16)
                    .onAppear { scrollProxy = proxy }
                    .onTapGesture {
                        isNoteFieldFocused = false
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .animation(ONEAnimation.panelSpring, value: showPhotoRow)
        .animation(ONEAnimation.panelSpring, value: showMoodSection)
        .animation(ONEAnimation.panelSpring, value: showNoteSection)
        .animation(ONEAnimation.panelSpring, value: showSaveButton)
        .animation(ONEAnimation.panelSpring, value: selectedSong != nil)
        .onChange(of: photoImage) { _, newPhoto in
            // v3: kamera çekimi de 9:16'ya normalize — galeriden gelenle
            // aynı çerçeveleme kuralı.
            if let raw = newPhoto,
               let cropped = raw.centerCropped(toAspect: 9.0 / 16.0),
               cropped.size != raw.size {
                photoImage = cropped
                return
            }
            guard newPhoto != nil, !showMoodSection, let proxy = scrollProxy else { return }
            reveal("moodSection", proxy: proxy) { showMoodSection = true }
        }
        .fullScreenCover(isPresented: $showCamera) { CameraView(image: $photoImage) }
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

    // Banners (memory card, now playing, photo overlay) extracted to TodayEmptyView+Banners.swift (Faz 3.1).
    // Steps (search → mood → feeling → note → save) extracted to TodayEmptyView+Steps.swift (Faz 3.1).
    // Helpers extracted to TodayEmptyView+Helpers.swift (Faz 3.1).
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
