//
//  TodayEmptyView+Steps.swift
//  one
//
//  Step views extracted from TodayEmptyView in Faz 3.1 (2026-04-26):
//  - Şarkı Arama, Seçilen Şarkı Kartı, Fotoğraf Satırı
//  - Mood Seçimi, Feeling Seçimi, Not Alanı
//  - Devam Et / Kaydet butonları
//
//  Kept as `extension TodayEmptyView` so SwiftUI state remains accessible.
//

import SwiftUI

extension TodayEmptyView {

    // MARK: - Şarkı Arama

    var songSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if selectedSong == nil {
                // Airbnb-tarzı: tighter kerning, daha kompakt başlık
                Text(NSLocalizedString("today.title", comment: ""))
                    .displayMD()
                    .fontWeight(.semibold)
                    .tracking(-0.6)
                    .foregroundColor(V3Tokens.ink)
                    .lineSpacing(0)
                    .padding(.bottom, 10)

                // Arama kutusu
                HStack(spacing: 10) {
                    if vm.isSearching {
                        ProgressView().scaleEffect(0.7).frame(width: 13, height: 13)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .bodySM()
                            .foregroundColor(V3Tokens.faintText)
                    }
                    TextField(NSLocalizedString("search.searchPlaceholder", comment: ""), text: $searchText)
                        .monoSM(tracking: 0)
                        .foregroundColor(V3Tokens.ink)
                        .onChange(of: searchText) { _, v in vm.search(v) }
                    if !searchText.isEmpty {
                        Button(action: { searchText = ""; vm.searchResults = [] }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(V3Tokens.faintText)
                                .bodySM()
                        }
                        .accessibilityLabel(NSLocalizedString("accessibility.today.clearSearch", comment: ""))
                        .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 13).fill(V3Tokens.hairline))

                // Son sanatçılar
                if searchText.isEmpty && !vm.recentArtists.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.recentArtists, id: \.self) { artist in
                                Button(action: { searchText = artist; vm.search(artist) }) {
                                    Text(artist)
                                        .monoSM(tracking: 0.6)
                                        .foregroundColor(V3Tokens.mutedText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Capsule().stroke(V3Tokens.surface, lineWidth: 1))
                                }
                                .accessibilityLabel(String(format: NSLocalizedString("accessibility.today.artistFilter", comment: ""), artist))
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
                                            CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                                                placeholder: { V3Tokens.hairline }
                                        } else { V3Tokens.hairline }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(song.name).bodyMD().foregroundColor(V3Tokens.ink).lineLimit(1).minimumScaleFactor(0.75)
                                        Text(song.artist).monoSM(tracking: 0).foregroundColor(V3Tokens.faintText)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel(String(format: NSLocalizedString("accessibility.today.searchResult", comment: ""), song.name, song.artist))
                            .accessibilityHint(NSLocalizedString("accessibility.today.searchResultHint", comment: ""))
                            Divider().background(V3Tokens.hairline)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.top, 4)
                }

                if let err = vm.searchError {
                    Text(err).monoSM(tracking: 0).foregroundColor(ONEBrand.kor.opacity(0.7)).padding(.top, 6)
                } else if !searchText.isEmpty && !vm.isSearching && vm.searchResults.isEmpty {
                    Text(NSLocalizedString("today.noResults", comment: "")).monoSM(tracking: 0).foregroundColor(V3Tokens.wash).padding(.top, 6)
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
                    CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                        placeholder: { V3Tokens.hairline }
                } else { V3Tokens.hairline }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(song.name).displaySM().foregroundColor(V3Tokens.ink).lineLimit(1).minimumScaleFactor(0.75)
                Text(song.artist).monoSM(tracking: 0).foregroundColor(V3Tokens.faintText)
            }
            Spacer()

            Button(action: { resetAll() }) {
                Text(NSLocalizedString("today.photoChange", comment: ""))
                    .monoSM(tracking: 1.0)
                    .foregroundColor(V3Tokens.wash)
            }
            .accessibilityLabel(NSLocalizedString("accessibility.today.changeSong", comment: ""))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(V3Tokens.hairline))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Fotoğraf Satırı

    var photoRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(photoImage != nil ? ONETokens.oneGreen.opacity(0.15) : V3Tokens.surface)
                    .frame(width: 40, height: 40)
                Image(systemName: photoImage != nil ? "checkmark" : "camera")
                    .bodyLG()
                    .fontWeight(.light)
                    .foregroundColor(photoImage != nil ? ONETokens.oneGreen : V3Tokens.mutedText)
            }
            Text(photoImage != nil ? "Fotoğraf eklendi" : NSLocalizedString("confirm.addPhoto", comment: ""))
                .bodyMD().foregroundColor(V3Tokens.ink)
            Spacer()
            if photoImage == nil {
                Text(NSLocalizedString("today.optional", comment: "")).monoSM(tracking: 0.5).foregroundColor(V3Tokens.faintText)
            }
            if photoImage != nil {
                Button(action: { withAnimation(ONEAnimation.micro) { photoImage = nil } }) {
                    Image(systemName: "xmark.circle.fill").displayXS().foregroundColor(V3Tokens.faintText)
                }
                .accessibilityLabel(NSLocalizedString("accessibility.today.removePhoto", comment: ""))
                .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(V3Tokens.hairline)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(photoImage != nil ? ONETokens.oneGreen.opacity(0.4) : Color.clear, lineWidth: 1))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard photoImage == nil else { return }
            ONEHaptics.feelingSelected()
            showCamera = true
        }
        .accessibilityLabel(
            photoImage != nil
                ? NSLocalizedString("accessibility.today.removePhoto", comment: "")
                : NSLocalizedString("accessibility.today.addPhoto", comment: "")
        )
    }

    func photoPreview(_ photo: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity).frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture { showFullScreenPhoto = true }
                .accessibilityLabel(NSLocalizedString("accessibility.today.photoPreview", comment: ""))
                .accessibilityHint(NSLocalizedString("accessibility.today.photoPreviewHint", comment: ""))
                .accessibilityAddTraits(.isImage)
            Button(action: { showCamera = true }) {
                Image(systemName: "arrow.counterclockwise")
                    .monoSM().fontWeight(.semibold).foregroundColor(.white)
                    .padding(9).background(Circle().fill(Color.black.opacity(0.45)))
            }
            .accessibilityLabel(NSLocalizedString("accessibility.today.retakePhoto", comment: ""))
            .padding(10)
        }
    }

    // MARK: - Mood Seçimi

    var moodSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("today.moodSection", comment: ""))
                .bodyLG()
                .fontWeight(.medium)
                .tracking(-0.2)
                .foregroundColor(V3Tokens.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                ForEach(MoodOption.all) { mood in
                    Button(action: {
                        ONEHaptics.moodSelected()
                        if selectedMood == nil {
                            AppAnalytics.shared.track(.moodPickedBeforeLabel)
                        }
                        withAnimation(ONEAnimation.micro) { selectedMood = mood }
                        AppAnalytics.shared.track(.moodLabelRevealedAfterPick(mood: mood.key))
                        if !showNoteSection, let proxy = scrollProxy {
                            reveal("noteSection", proxy: proxy) { showNoteSection = true }
                        }
                    }) {
                        VStack(spacing: 7) {
                            Circle()
                                .fill(mood.color)
                                .frame(width: 44, height: 44)
                                .overlay(Circle()
                                    .stroke(V3Tokens.ink, lineWidth: selectedMood?.key == mood.key ? 2 : 0)
                                    .padding(-3))
                                .scaleEffect(selectedMood?.key == mood.key ? 1.08 : 1.0)
                                .animation(ONEAnimation.micro, value: selectedMood?.key)
                            Text(mood.label)
                                .monoLabel(tracking: 0.2)
                                .foregroundColor(selectedMood?.key == mood.key ? ONETokens.oneGraphite : V3Tokens.faintText)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                // #02 Renk-önce: label seçimden önce gizli, sonra 200ms fade-in
                                .opacity(selectedMood == nil ? 0 : (selectedMood?.key == mood.key ? 1 : 0.35))
                                .animation(.easeIn(duration: 0.2), value: selectedMood?.key)
                        }
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("accessibility.confirm.moodButton", comment: ""), mood.label))
                    .accessibilityAddTraits(selectedMood?.key == mood.key ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Not Alanı

    var noteField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("today.noteSection", comment: ""))
                .bodyLG()
                .fontWeight(.medium)
                .tracking(-0.2)
                .foregroundColor(V3Tokens.ink)

            HStack(spacing: 12) {
                TextField(NSLocalizedString("today.notePlaceholder", comment: ""), text: $dailyNote)
                    .monoSM(tracking: 0).foregroundColor(V3Tokens.ink)
                    .submitLabel(.done).focused($isNoteFieldFocused)
                    .onSubmit { isNoteFieldFocused = false }
                if !dailyNote.isEmpty {
                    Button(action: { dailyNote = "" }) {
                        Image(systemName: "xmark.circle.fill").bodySM().foregroundColor(V3Tokens.faintText)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                    .fill(isNoteFieldFocused ? V3Tokens.surface : V3Tokens.hairline)
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
                    .foregroundColor(enabled ? V3Tokens.ink : V3Tokens.faintText)
                Image(systemName: "arrow.down")
                    .monoSM()
                    .fontWeight(.semibold)
                    .foregroundColor(enabled ? V3Tokens.ink : V3Tokens.faintText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18).padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(enabled ? Color.primary.opacity(0.07) : Color.primary.opacity(0.03))
                    .overlay(Capsule().stroke(enabled ? Color.primary.opacity(0.18) : Color.clear, lineWidth: 1))
            )
        }
        .disabled(!enabled)
        .animation(ONEAnimation.micro, value: enabled)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityLabel(label)
    }

    // MARK: - Kaydet Butonu

    var saveButton: some View {
        VStack(spacing: 14) {
            // Çevre paylaşım toggle — her zaman göster (fotoğrafsız da paylaşılabilir)
            CircleShareToggle(isOn: $sharePhoto, hasPhoto: photoImage != nil)

            Text(NSLocalizedString("onboarding.slogan", comment: ""))
                .monoSM(tracking: 1.2)
                .foregroundColor(V3Tokens.mutedText)

            // Ana CTA
            Button(action: {
                guard let song = selectedSong,
                      let mood = selectedMood else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                vm.saveEntry(song: song, mood: mood,
                             photo: photoImage, note: dailyNote, sharePhoto: sharePhoto)
            }) {
                Text(NSLocalizedString("confirm.todaySong", comment: ""))
                    .displayXS()
                    .foregroundColor(ONEBrand.bone)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedMood?.color ?? V3Tokens.ink)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .animation(ONEAnimation.micro, value: selectedMood?.key)
            .accessibilityLabel(NSLocalizedString("accessibility.today.saveButton", comment: ""))

            // Şarkıyı değiştir
            Button(action: { resetAll() }) {
                Text(NSLocalizedString("today.changeSong", comment: ""))
                    .monoSM(tracking: 0.8).foregroundColor(V3Tokens.faintText)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }

    // MARK: - #10 Pas Butonu

    var passButton: some View {
        Button(action: {
            vm.markTodayAsPassed()
        }) {
            Text(NSLocalizedString("today.passButton", comment: ""))
                .monoSM(tracking: 0.8)
                .foregroundColor(V3Tokens.faintText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .accessibilityLabel(NSLocalizedString("today.passButton", comment: ""))
    }

}
