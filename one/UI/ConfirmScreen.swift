//
//  ConfirmScreen.swift
//  one
//
//  Song confirmation screen with mood/feeling selection
//

import SwiftUI
import CoreData

struct ConfirmScreen: View {
    @ObservedObject var vm: ColorPickerViewModel
    let viewContext: NSManagedObjectContext
    let moodCoreNS: Namespace.ID

    // CTA bar fixed height for scroll padding
    private let ctaBarHeight: CGFloat = 120

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Scrollable content ──────────────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {

                    // Header
                    HStack {
                        Button(action: { vm.currentScreen = .search }) {
                            Text(NSLocalizedString("confirm.back", comment: ""))
                                .monoBase(tracking: 1.5)
                                .foregroundColor(ONETokens.oneAsh)
                        }
                        .accessibilityLabel(NSLocalizedString("general.back", comment: ""))
                        .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                        .contentShape(Rectangle())
                        Spacer()
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 16)

                    if let song = vm.selectedSong {

                        // ── Hero: Albüm kapağı + Fotoğraf butonu yan yana ──
                        HStack(alignment: .top, spacing: 14) {

                            // Sol: Albüm kapağı (küçülür fotoğraf seçilince)
                            ZStack {
                                if let artworkURL = song.artworkURL {
                                    CachedAsyncImagePhase(url: artworkURL) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(ONETokens.oneCreamMid)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .shadow(color: song.shadow, radius: 16, x: 0, y: 8)
                                } else {
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(LinearGradient(
                                            gradient: Gradient(colors: song.grad),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .shadow(color: song.shadow, radius: 16, x: 0, y: 8)
                                        .overlay(Text(song.emoji).font(.system(size: 36)))
                                }
                            }
                            .frame(
                                width: vm.selectedPhoto != nil ? 90 : 160,
                                height: vm.selectedPhoto != nil ? 90 : 160
                            )
                            .animation(ONEAnimation.cardSpring, value: vm.selectedPhoto != nil)
                            .accessibilityHidden(true)

                            // Sağ: Fotoğraf alanı
                            PhotoHeroButton(selectedPhoto: $vm.selectedPhoto)
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .animation(ONEAnimation.cardSpring, value: vm.selectedPhoto != nil)
                                .accessibilityLabel(
                                    vm.selectedPhoto != nil
                                        ? NSLocalizedString("accessibility.today.removePhoto", comment: "")
                                        : NSLocalizedString("accessibility.today.addPhoto", comment: "")
                                )
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 28)

                        // Şarkı bilgisi
                        VStack(alignment: .leading, spacing: 3) {
                            Text(song.name)
                                .displaySM()
                                .foregroundColor(ONETokens.oneInk)
                                .tracking(-0.02)
                                .lineLimit(1)
                            Text("\(song.artist) · \(song.genre)")
                                .monoBase(tracking: 0.5)
                                .foregroundColor(ONETokens.oneAsh)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 26)
                        .padding(.top, 18)

                        // ── Mood seçimi ──────────────────────────────────────
                        HStack {
                            Text(NSLocalizedString("confirm.moodQuestion", comment: ""))
                                .monoBase(tracking: 1.5)
                                .foregroundColor(ONETokens.oneAsh)
                            Spacer()
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 32)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                            spacing: 20
                        ) {
                            ForEach(ONEMood.allCases) { mood in
                                let isSelected = vm.selectedMood?.id == mood.id
                                ZStack {
                                    MoodButton(mood: mood, isSelected: isSelected) {
                                        ONEHaptics.moodSelected()
                                        withAnimation(ONEAnimation.micro) { vm.selectedMood = mood }
                                    }
                                    // matchedGeometryEffect source — mood circle "travels" to DoneScreen
                                    if isSelected {
                                        Circle()
                                            .fill(mood.color)
                                            .frame(width: 56, height: 56)
                                            .matchedGeometryEffect(id: "moodCore", in: moodCoreNS)
                                            .allowsHitTesting(false)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 16)

                        // ── Feeling seçimi (mood seçilince) ─────────────────
                        if vm.selectedMood != nil {
                            HStack {
                                Text(NSLocalizedString("confirm.question", comment: ""))
                                    .monoBase(tracking: 1.5)
                                    .foregroundColor(ONETokens.oneAsh)
                                Spacer()
                            }
                            .padding(.horizontal, 26)
                            .padding(.top, 28)
                            .transition(.opacity.combined(with: .move(edge: .top)))

                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4),
                                spacing: 20
                            ) {
                                ForEach(FeelingOption.all) { feeling in
                                    FeelingButton(
                                        feeling: feeling,
                                        isSelected: vm.selectedFeeling?.type == feeling.type,
                                        action: {
                                            withAnimation(ONEAnimation.micro) {
                                                vm.selectedFeeling = feeling
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.top, 16)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // ── Not satırı (inline, kompakt) ────────────────────
                        if vm.selectedMood != nil {
                            InlineNoteField(noteText: $vm.dailyNote)
                                .padding(.horizontal, 26)
                                .padding(.top, 20)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))

                            // Circle paylaşım toggle (fotoğraf varsa)
                            if vm.selectedPhoto != nil {
                                CircleShareToggle(
                                    isOn: $vm.shareWithCircle,
                                    hasPhoto: true
                                )
                                .padding(.horizontal, 26)
                                .padding(.top, 12)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }

                        // Sabit CTA barı için boşluk
                        Color.clear.frame(height: ctaBarHeight + 16)
                    }
                }
            }

            // ── Sabit CTA barı ───────────────────────────────────────────────
            VStack(spacing: 0) {
                // Üst blur kenarı
                LinearGradient(
                    colors: [ONETokens.oneCream.opacity(0), ONETokens.oneCream],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 24)

                VStack(spacing: 12) {
                        Button(action: {
                            ONEHaptics.saveRitual(mood: vm.selectedMood)
                            vm.saveTodaysSong(context: viewContext)
                            vm.currentScreen = .done
                        }) {
                            Text(NSLocalizedString("confirm.todaySong", comment: ""))
                                .displayXS()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    (vm.selectedFeeling != nil ? vm.selectedMood?.color : nil)
                                        ?? ONETokens.oneStone
                                )
                                .foregroundColor(
                                    vm.selectedMood?.isDark == false ? .black : ONETokens.oneCream
                                )
                                .cornerRadius(20)
                        }
                        .disabled(vm.selectedMood == nil || vm.selectedFeeling == nil)
                        .animation(ONEAnimation.micro, value: vm.selectedMood != nil && vm.selectedFeeling != nil)
                        .accessibilityLabel(NSLocalizedString("today.saveButton", comment: ""))

                        Button(action: { vm.currentScreen = .search }) {
                            Text(NSLocalizedString("today.photoChange", comment: ""))
                                .monoBase(tracking: 1.5)
                                .foregroundColor(ONETokens.oneAsh)
                        }
                        .accessibilityLabel(NSLocalizedString("general.back", comment: ""))
                        .frame(minWidth: ONETokens.minTouchTarget, minHeight: ONETokens.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 28)
                .background(ONETokens.oneCream)
            }
        }
    }
}

// MARK: - Photo Hero Button
/// Albüm kapağının yanında büyük fotoğraf seçim alanı.
/// Fotoğraf seçilmemişse dashed border + ikon gösterir.
/// Seçilmişse fotoğrafı tam doldurur, köşede küçük "değiştir" butonu çıkar.
struct PhotoHeroButton: View {
    @Binding var selectedPhoto: UIImage?
    @State private var showCamera = false

    var body: some View {
        Button(action: { showCamera = true }) {
            ZStack(alignment: .bottomTrailing) {
                if let photo = selectedPhoto {
                    // Fotoğraf seçildi — tam doldur
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )

                    // Değiştir rozeti
                    ZStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ONETokens.oneInk)
                            .frame(width: 32, height: 32)
                            .liquidGlass(in: Circle())
                    }
                    .padding(8)

                } else {
                    // Boş durum — dashed + ikon
                    RoundedRectangle(cornerRadius: 18)
                        .fill(ONETokens.oneCreamMid)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                                )
                                .foregroundColor(ONETokens.oneStone)
                        )

                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(ONETokens.oneAsh)
                        Text(NSLocalizedString("confirm.addPhoto", comment: ""))
                            .monoSM(tracking: 0.5)
                            .foregroundColor(ONETokens.oneAsh)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(selectedImage: $selectedPhoto)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Inline Note Field
/// Kompakt tek satır not alanı. Büyük kart değil, hafif arka planlı satır.
struct InlineNoteField: View {
    @Binding var noteText: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pencil.line")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(ONETokens.oneAsh)

            TextField(NSLocalizedString("today.notePlaceholder", comment: ""), text: $noteText)
                .monoBase(tracking: 0.2)
                .foregroundColor(ONETokens.oneInk)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { isFocused = false }

            if !noteText.isEmpty {
                Button(action: { noteText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(ONETokens.oneStone)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: ONETokens.radiusCard)
                .fill(isFocused ? ONETokens.onePaper : ONETokens.oneCreamMid)
                .shadow(
                    color: isFocused ? Color.black.opacity(0.07) : Color.clear,
                    radius: 10, x: 0, y: 3
                )
                .animation(ONEAnimation.micro, value: isFocused)
        )
    }
}
