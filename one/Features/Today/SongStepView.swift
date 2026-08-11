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


    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Prototipte tek satır soru var — tarih eyebrow'u ve
                // açıklama cümlesi ritüelin ikinci adımını yavaşlatıyordu.
                Text("bugünün şarkısı?")
                    .displayMD()
                    .foregroundStyle(V3Tokens.ink)
                    .padding(.bottom, ONETokens.spacingMD)

                // "Şu an çalıyor" banner'ı yok — prototipte adım
                // arama + liste + paylaş + bırak, o kadar.

                searchField
                    .padding(.top, 8)

                // "Son sanatçılar" ve "SANA YAKIN" blokları kaldırıldı:
                // prototipte adım arama + liste, o kadar. Öneriler seçimi
                // hızlandırmıyor, erteliyordu — kullanıcı zaten aklındaki
                // şarkıyı aramaya geliyor.

                if let err = vm.searchError, !err.isEmpty, !vm.isSearching {
                    // Retry closure body içinde tanımlanır ki `searchText`
                    // doğrudan @State property wrapper'ından okunsun; helper
                    // fonksiyona geçirilen kapatmalarda closure'un yakaladığı
                    // struct kopyasından okumak riskli olmasın diye.
                    searchErrorRow(err, onRetry: { vm.search(searchText) })
                        .padding(.top, 12)
                } else if !vm.searchResults.isEmpty {
                    searchResultsList
                        .padding(.top, 4)
                } else if !searchText.isEmpty && !vm.isSearching {
                    Text("Bir şey yaz, başlayalım.")
                        .monoSM(tracking: 0)
                        .foregroundStyle(V3Tokens.faintText)
                        .padding(.top, 8)
                }

                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, 24)
            // 100pt, üst çubuk overlay'ken onun altından çıkmak içindi.
            // Çubuk artık düzenin içinde; bu boşluk aramayı ekranın
            // ortasına itiyordu.
            .padding(.top, ONETokens.spacingMD)
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
                        .foregroundStyle(ONEBrand.bone)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(coordinator.draft.mood?.color ?? V3Tokens.ink)
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
                    colors: [ONEBrand.bone.opacity(0), ONEBrand.bone],
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
                                     ? V3Tokens.ink : V3Tokens.faintText)

                VStack(alignment: .leading, spacing: 1) {
                    Text("çevrene göster")
                        .font(ONETypography.bodySM)
                        .fontWeight(.medium)
                        .foregroundStyle(V3Tokens.ink)
                    Text("rengin ve şarkın frekansta görünsün")
                        .font(ONETypography.monoMicro)
                        .foregroundStyle(V3Tokens.mutedText)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                    .fill(V3Tokens.surface)
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
                    .foregroundStyle(V3Tokens.faintText)
            }
            TextField("şarkı veya sanatçı", text: $searchText)
                .monoSM(tracking: 0)
                .foregroundStyle(V3Tokens.ink)
                .onChange(of: searchText) { _, v in vm.search(v) }
            if !searchText.isEmpty {
                Button(action: { searchText = ""; vm.searchResults = []; vm.searchError = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(V3Tokens.faintText)
                        .bodySM()
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Aramayı temizle"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 13).fill(V3Tokens.hairline))
    }

    @ViewBuilder
    private func searchErrorRow(_ message: String, onRetry: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(V3Tokens.faintText)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .bodySM()
                    .foregroundStyle(V3Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onRetry) {
                    Text("tekrar dene")
                        .font(ONETypography.monoSM)
                        .tracking(0.6)
                        .foregroundStyle(V3Tokens.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().stroke(V3Tokens.ink.opacity(0.14), lineWidth: 1)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Aramayı tekrar dene"))
            }
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }




    private var searchResultsList: some View {
        songSection(songs: vm.searchResults, header: "Sonuçlar")
    }

    private func songSection(songs: [SongResult], header: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header)
                .font(ONETypography.monoMicro)
                .tracking(1.4)
                .foregroundStyle(V3Tokens.faintText)
                .textCase(.uppercase)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                ForEach(songs) { song in
                    songRow(song)
                    if song.id != songs.last?.id {
                        Divider().background(V3Tokens.hairline)
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
                                CachedAsyncImage(url: url, maxPixelSize: ImageCache.thumbnailMaxPixelSize) { img in img.resizable().scaledToFill() }
                                    placeholder: { V3Tokens.hairline }
                            } else if let url = song.coverURL {
                                CachedAsyncImage(url: url, maxPixelSize: ImageCache.thumbnailMaxPixelSize) { img in img.resizable().scaledToFill() }
                                    placeholder: { V3Tokens.hairline }
                            } else {
                                V3Tokens.hairline
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
                        Text(song.name).bodyMD().foregroundStyle(V3Tokens.ink).lineLimit(1)
                        Text(song.artist).monoSM(tracking: 0).foregroundStyle(V3Tokens.faintText)
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
                            .foregroundStyle(V3Tokens.faintText)
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

}
