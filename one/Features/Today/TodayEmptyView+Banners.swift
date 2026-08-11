//
//  TodayEmptyView+Banners.swift
//  one
//
//  Banner-style sections extracted from TodayEmptyView in Faz 3.1 (2026-04-26):
//  - Bu Gün Geçen Yıl Hafıza Kartı, Section Divider, Şimdi Çalıyor Banner
//  - Tam Ekran Fotoğraf overlay
//
//  Kept as `extension TodayEmptyView` so SwiftUI state remains accessible.
//

import SwiftUI

extension TodayEmptyView {

    // MARK: - Bu Gün Geçen Yıl Hafıza Kartı

    func lastYearMemoryCard(_ entry: DailyEntry) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(entry.moodColor)
                .frame(width: 10, height: 10)
                .padding(.leading, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("365 gün önce")
                    .monoLabel(tracking: 1.0)
                    .foregroundColor(V3Tokens.mutedText)
                Text(entry.songName)
                    .bodySMMedium()
                    .foregroundColor(V3Tokens.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(entry.artistName)
                    .monoSM(tracking: 0)
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            Text(entry.normalizedMoodLabel.uppercased())
                .monoLabel(tracking: 1.0)
                .foregroundColor(entry.moodColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(entry.moodColor.opacity(0.12)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("accessibility.today.lastYear", comment: ""), entry.songName, entry.artistName, entry.normalizedMoodLabel))
    }

    // MARK: - C3 — 1 Hafta Önce Bugün (Mini Echo)

    /// Mini Echo: bir hafta önce bu tarihte yaptığın entry'yi gösterir.
    /// Variable reward + nostalji — D14+ için anlamlı bir geri çağrı.
    func lastWeekMemoryCard(_ entry: DailyEntry) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(entry.moodColor)
                .frame(width: 10, height: 10)
                .padding(.leading, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("7 gün önce")
                    .monoLabel(tracking: 1.0)
                    .foregroundColor(V3Tokens.mutedText)
                Text(entry.songName)
                    .bodySMMedium()
                    .foregroundColor(V3Tokens.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(entry.artistName)
                    .monoSM(tracking: 0)
                    .foregroundColor(V3Tokens.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            Text(entry.normalizedMoodLabel.uppercased())
                .monoLabel(tracking: 1.0)
                .foregroundColor(entry.moodColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(entry.moodColor.opacity(0.12)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(V3Tokens.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(V3Tokens.hairline, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("7 gün önce \(entry.songName), \(entry.artistName), \(entry.normalizedMoodLabel)")
    }

    // MARK: - Section Divider

    var sectionDivider: some View {
        Rectangle()
            .fill(V3Tokens.hairline)
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
                genre: NSLocalizedString("genre.music", comment: ""),
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
                        CachedAsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            V3Tokens.hairline
                        }
                    } else {
                        V3Tokens.hairline
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
                        Text(track.source == .spotify ? NSLocalizedString("today.playingOnSpotify", comment: "") : NSLocalizedString("today.playingOnAppleMusic", comment: ""))
                            .monoLabel(tracking: 0.8)
                            .foregroundColor(track.source == .spotify ? ONETokens.spotifyGreen : ONETokens.appleMusicRed)
                    }
                    Text(track.name)
                        .bodyMD()
                        .foregroundColor(V3Tokens.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(track.artist)
                        .monoSM(tracking: 0)
                        .foregroundColor(V3Tokens.faintText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer()

                // Seç butonu
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(V3Tokens.ink)
                    Text(NSLocalizedString("today.select", comment: ""))
                        .monoLabel(tracking: 0.5)
                        .foregroundColor(V3Tokens.faintText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(V3Tokens.surface)
                    .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(NSLocalizedString("accessibility.today.nowPlayingBanner", comment: ""))
        .accessibilityHint(NSLocalizedString("accessibility.today.nowPlayingBannerHint", comment: ""))
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
                            DragGesture(minimumDistance: 5)
                                .onChanged { val in
                                    if photoZoomScale > 1.01 {
                                        let maxX = (photoZoomScale - 1) * geo.size.width  / 2
                                        let maxY = (photoZoomScale - 1) * geo.size.height / 2
                                        photoPanOffset = CGSize(
                                            width:  min(max(photoLastPanOffset.width  + val.translation.width,  -maxX), maxX),
                                            height: min(max(photoLastPanOffset.height + val.translation.height, -maxY), maxY)
                                        )
                                    } else {
                                        let dy = val.translation.height
                                        if dy > 0 { photoDismissOffset = dy }
                                    }
                                }
                                .onEnded { val in
                                    if photoZoomScale > 1.01 {
                                        photoLastPanOffset = photoPanOffset
                                    } else {
                                        let vel = val.velocity.height
                                        let dy  = val.translation.height
                                        let shouldDismiss = dy > 90 || (dy > 20 && vel > 600)
                                        if shouldDismiss {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            withAnimation(.easeOut(duration: 0.28)) {
                                                photoDismissOffset = UIScreen.main.bounds.height
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                                showFullScreenPhoto = false
                                                photoZoomScale = 1.0
                                                photoLastZoomScale = 1.0
                                                photoDismissOffset = 0
                                                photoPanOffset = .zero
                                                photoLastPanOffset = .zero
                                            }
                                        } else {
                                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                                                photoDismissOffset = 0
                                            }
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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeOut(duration: 0.22)) {
                            photoDismissOffset = UIScreen.main.bounds.height
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            showFullScreenPhoto = false
                            photoDismissOffset = 0
                            photoZoomScale = 1.0
                            photoLastZoomScale = 1.0
                            photoPanOffset = .zero
                            photoLastPanOffset = .zero
                        }
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

}
