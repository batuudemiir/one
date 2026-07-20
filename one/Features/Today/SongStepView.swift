//
//  SongStepView.swift
//  one
//

import SwiftUI

struct SongStepView: View {
    @ObservedObject var coordinator: TodayCoordinator
    @ObservedObject var vm: TodayViewModel
    @State private var searchText = ""
    @ObservedObject private var nowPlaying = NowPlayingManager.shared
    @ObservedObject private var previewer = SongPreviewPlayer.shared

    private var dateEyebrow: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "tr_TR")
        df.dateFormat = "d MMMM, HH:mm"
        return df.string(from: Date())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Prototipte tek satır soru var — tarih eyebrow'u ve
                // açıklama cümlesi ritüelin ikinci adımını yavaşlatıyordu.
                Text("bugünün şarkısı?")
                    .displayMD()
                    .foregroundStyle(ONETokens.oneInk)
                    .padding(.bottom, ONETokens.spacingMD)

                if let track = nowPlaying.currentTrack {
                    nowPlayingBanner(track: track)
                        .padding(.bottom, 4)
                }

                searchField
                    .padding(.top, 8)

                // "Son sanatçılar" ve "SANA YAKIN" blokları kaldırıldı:
                // prototipte adım arama + liste, o kadar. Öneriler seçimi
                // hızlandırmıyor, erteliyordu — kullanıcı zaten aklındaki
                // şarkıyı aramaya geliyor. (Bölümlerin kodu duruyor.)

                if !vm.searchResults.isEmpty {
                    searchResultsList
                        .padding(.top, 4)
                } else if !searchText.isEmpty && !vm.isSearching {
                    Text("Bir şey yaz, başlayalım.")
                        .monoSM(tracking: 0)
                        .foregroundStyle(ONETokens.oneMist)
                        .padding(.top, 8)
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 24)
            .padding(.top, 100)
        }
        .onAppear {
            nowPlaying.startPolling()
            vm.loadRecommendedSongs()
        }
        .onDisappear {
            nowPlaying.stopPolling()
        }
        // Şarkı son adım — paylaşım tercihi ve "bırak" burada.
        .overlay(alignment: .bottom) { commitBar }
    }

    // MARK: - Commit Bar (son adım)

    @ViewBuilder
    private var commitBar: some View {
        if let song = coordinator.draft.song {
            VStack(spacing: 10) {
                shareToggleRow

                Button(action: { coordinator.next() }) {
                    Text("bırak")
                        .font(ONETypography.bodyMD)
                        .fontWeight(.semibold)
                        .foregroundStyle(ONETokens.oneCream)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(coordinator.draft.mood?.color ?? ONETokens.oneInk)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(song.name) — bırak")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .padding(.top, 14)
            .background(
                LinearGradient(
                    colors: [ONETokens.oneCream.opacity(0), ONETokens.oneCream],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(ONEAnimation.cardSpring, value: coordinator.draft.song?.id)
        }
    }

    private var shareToggleRow: some View {
        Button(action: {
            ONEHaptics.feelingSelected()
            coordinator.draft.shareToCircle.toggle()
        }) {
            HStack(spacing: 10) {
                Image(systemName: coordinator.draft.shareToCircle
                      ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(coordinator.draft.shareToCircle
                                     ? ONETokens.oneInk : ONETokens.oneMist)

                VStack(alignment: .leading, spacing: 1) {
                    Text("çevrene göster")
                        .font(ONETypography.bodySM)
                        .fontWeight(.medium)
                        .foregroundStyle(ONETokens.oneShadow)
                    Text("rengin ve şarkın frekansta görünsün")
                        .font(ONETypography.monoMicro)
                        .foregroundStyle(ONETokens.oneAsh)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                    .fill(ONETokens.oneCreamMid)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(coordinator.draft.shareToCircle ? .isSelected : [])
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            if vm.isSearching {
                ProgressView().scaleEffect(0.7).frame(width: 13, height: 13)
            } else {
                Image(systemName: "magnifyingglass")
                    .bodySM()
                    .foregroundStyle(ONETokens.oneMist)
            }
            TextField("şarkı veya sanatçı", text: $searchText)
                .monoSM(tracking: 0)
                .foregroundStyle(ONETokens.oneShadow)
                .onChange(of: searchText) { _, v in vm.search(v) }
            if !searchText.isEmpty {
                Button(action: { searchText = ""; vm.searchResults = [] }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ONETokens.oneMist)
                        .bodySM()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 13).fill(ONETokens.oneSilver))
    }

    private var recentArtistsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Son sanatçılar")
                .font(.custom("DMSans24pt-Medium", size: 9))
                .tracking(1.4)
                .foregroundStyle(ONETokens.oneMist)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.recentArtists, id: \.self) { artist in
                        Button(action: { searchText = artist; vm.search(artist) }) {
                            Text(artist)
                                .monoSM(tracking: 0.6)
                                .foregroundStyle(ONETokens.oneAsh)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().stroke(ONETokens.oneCreamMid, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recommendedSongsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SANA YAKIN")
                    .font(ONETypography.monoMicro)
                    .tracking(1.4)
                    .foregroundStyle(ONETokens.oneMist)
                Spacer()
                Button {
                    vm.refreshRecommendedSongs()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ONETokens.oneMist)
                }
                .accessibilityLabel("Önerileri yenile")
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(vm.recommendedSongs) { song in
                    songRow(song)
                    if song.id != vm.recommendedSongs.last?.id {
                        Divider().background(ONETokens.oneSilver)
                    }
                }
            }
        }
    }

    private var recommendedSongsLoadingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SANA YAKIN")
                .font(ONETypography.monoMicro)
                .tracking(1.4)
                .foregroundStyle(ONETokens.oneMist)
                .padding(.bottom, 4)
            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ONETokens.oneSilver)
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ONETokens.oneSilver)
                            .frame(width: [130, 110, 145, 100][i], height: 11)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ONETokens.oneCreamMid)
                            .frame(width: [80, 90, 70, 85][i], height: 9)
                    }
                    Spacer()
                }
                .shimmeringCircle()
                if i < 3 { Divider().background(ONETokens.oneSilver) }
            }
        }
    }

    private var searchResultsList: some View {
        songSection(songs: vm.searchResults, header: "Sonuçlar")
    }

    private func songSection(songs: [SongResult], header: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header)
                .font(ONETypography.monoMicro)
                .tracking(1.4)
                .foregroundStyle(ONETokens.oneMist)
                .textCase(.uppercase)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(songs) { song in
                    songRow(song)
                    if song.id != songs.last?.id {
                        Divider().background(ONETokens.oneSilver)
                    }
                }
            }
        }
    }

    private func songRow(_ song: SongResult) -> some View {
        let isPlaying = previewer.playingID == song.id
        let isLoading = previewer.loadingID == song.id

        return HStack(spacing: 0) {
            Button(action: { previewer.toggle(song) }) {
                HStack(spacing: 12) {
                    ZStack {
                        Group {
                            if let urlStr = song.artworkURLString, let url = URL(string: urlStr) {
                                CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                    placeholder: { ONETokens.oneSilver }
                            } else if let url = song.coverURL {
                                CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                    placeholder: { ONETokens.oneSilver }
                            } else {
                                ONETokens.oneSilver
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        if isPlaying {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.35))
                                .frame(width: 40, height: 40)
                            AudioWaveform()
                        } else if isLoading {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.25))
                                .frame(width: 40, height: 40)
                            ProgressView().scaleEffect(0.65).tint(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.name).bodyMD().foregroundStyle(ONETokens.oneShadow).lineLimit(1)
                        Text(song.artist).monoSM(tracking: 0).foregroundStyle(ONETokens.oneMist)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: { selectSong(song) }) {
                Group {
                    if isPlaying {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(ONETokens.oneVoid)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(ONETokens.oneStone)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(.vertical, 10)
        .animation(.easeOut(duration: 0.15), value: isPlaying)
        .animation(.easeOut(duration: 0.15), value: isLoading)
    }

    private func selectSong(_ song: SongResult) {
        ONEHaptics.feelingSelected()
        withAnimation(ONEAnimation.cardSpring) {
            coordinator.draft.song = song
        }
        AppAnalytics.shared.track(.songSelected(source: "search"))
        // `next()` çağrılmıyor: şarkı artık son adım, kaydetme kararını
        // commitBar'daki "bırak" veriyor. Aksi halde kullanıcı paylaşım
        // tercihini göremeden kayıt olurdu.
    }

    @ViewBuilder
    private func nowPlayingBanner(track: NowPlayingTrack) -> some View {
        Button(action: {
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
                Image(systemName: "music.note")
                    .bodyMD()
                    .foregroundStyle(ONETokens.oneAsh)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Şu an çalıyor")
                        .font(ONETypography.monoMicro)
                        .tracking(1.4)
                        .foregroundStyle(ONETokens.oneMist)
                        .textCase(.uppercase)
                    Text(track.name)
                        .bodySM()
                        .foregroundStyle(ONETokens.oneShadow)
                        .lineLimit(1)
                    Text(track.artist)
                        .monoSM(tracking: 0)
                        .foregroundStyle(ONETokens.oneMist)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .monoSM()
                    .foregroundStyle(ONETokens.oneMist)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(ONETokens.oneSilver))
        }
        .buttonStyle(.plain)
    }
}
