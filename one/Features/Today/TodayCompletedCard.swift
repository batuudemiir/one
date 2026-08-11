//
//  TodayCompletedCard.swift
//  one
//
//  Kaydedildi ekranının ana kartı: fotoğraf/mood başlığı, şarkı bilgisi,
//  mood etiketi, not ve eylem butonları. `TodayCompletedView.swift`'ten
//  ayrıldı. Kendi sunum durumunu (paylaş/değiştir/kaydet) sahipleniyor —
//  bu state yalnız kartın içinden tetikleniyordu.
//

import SwiftUI

struct CompletedEntryCard: View {
    let entry: DailyEntry
    /// GeometryReader'dan gelen kullanılabilir yükseklik — foto yüksekliği
    /// buna göre ölçekleniyor.
    let available: CGFloat
    /// "Değiştir" onayı buradan çağrılır — yıkıcı, bugünü sıfırlar.
    let onEdit: () -> Void
    /// Kayıt sonrası opsiyonel ekler. nil ise ilgili davet gösterilmez.
    let onAddPhoto: (() -> Void)?
    let onAddNote: (() -> Void)?
    /// Fotoğraf tam ekranı — parent `GlobalUIState` ile eşgüdümlediği için
    /// binding olarak dışarıda tutuluyor.
    @Binding var showPhotoViewer: Bool

    /// Root'tan gelen hero namespace. Yoksa lokal fallback kullanılıyor,
    /// böylece preview/izole kullanımlar da çalışıyor.
    @Environment(\.todayPhotoNamespace) private var envPhotoNS
    @Namespace private var localPhotoNS
    private var photoNS: Namespace.ID { envPhotoNS ?? localPhotoNS }

    @State private var showShareOptions = false
    @State private var showChangeConfirm = false
    @State private var photoSaved = false

    /// Photo height: ~23 % of available height, hard-capped at 175 pt.
    private func photoHeight(available: CGFloat) -> CGFloat {
        max(90, min(175, available * 0.23))
    }

    var body: some View {
        VStack(spacing: 0) {
            photoOrMoodHeader
            songInfoSection
        }
        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sheet(isPresented: $showShareOptions) {
            ONEShareSheet(entry: entry)
        }
        .confirmationDialog(
            NSLocalizedString("today.changeConfirmTitle", comment: ""),
            isPresented: $showChangeConfirm,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("today.changeConfirmYes", comment: ""), role: .destructive) {
                onEdit()
            }
            Button(NSLocalizedString("general.cancel", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("today.changeConfirmMessage", comment: ""))
        }
    }

    // MARK: - Photo / mood header

    private var photoOrMoodHeader: some View {
        ZStack(alignment: .bottomLeading) {
            if let photoURL = entry.photoURL {
                // Photo background - tıklanabilir
                Button(action: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        showPhotoViewer = true
                    }
                }) {
                    CachedAsyncImagePhase(url: photoURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            V3Tokens.surface
                                .overlay(ONEMood(hex: entry.moodColorHex)?.atmosphereGradient())
                        }
                    }
                    .frame(height: photoHeight(available: available))
                    .clipped()
                    .matchedGeometryEffect(id: "todayPhoto", in: photoNS, isSource: !showPhotoViewer)
                    .opacity(showPhotoViewer ? 0 : 1)
                    .overlay(
                        // Subtle tap indicator
                        ZStack {
                            Color.black.opacity(0.02)
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .bodySMMedium()
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .opacity(showPhotoViewer ? 0 : 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(String(format: NSLocalizedString("accessibility.today.photoOf", comment: ""), entry.songName))
                .accessibilityHint(NSLocalizedString("accessibility.today.photoPreviewHint", comment: "Fotoğrafı tam ekranda görüntülemek için dokunun"))
                .accessibilityAddTraits(.isButton)
            } else {
                // No photo — mood color clearly visible
                if let mood = ONEMood(hex: entry.moodColorHex) {
                    LinearGradient(
                        stops: [
                            .init(color: mood.pastelColor,              location: 0.0),
                            .init(color: mood.pastelColor.opacity(0.5), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    V3Tokens.hairline
                }
            }

            // Time badge
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 6, height: 6)
                Text(String(format: NSLocalizedString("today.timeSelected", comment: ""), entry.time))
                    .monoLabel(tracking: 1.0)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, ONETokens.spacingMD)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(20)
        }
        .frame(height: photoHeight(available: available))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Song info

    private var songInfoSection: some View {
        VStack(alignment: .leading, spacing: ONETokens.spacingLG) {
            // Song name + artist — tappable to change
            Button(action: {
                ONEHaptics.feelingSelected()
                showChangeConfirm = true
            }) {
                VStack(alignment: .leading, spacing: ONETokens.spacingLG) {
                    // Song name
                    Text(entry.songName)
                        .displayMD()
                        .foregroundColor(V3Tokens.ink)
                        .tracking(-0.8)
                        .lineLimit(2)

                    // Artist & genre
                    Text("\(entry.artistName) · \(entry.genre)")
                        .monoBase(tracking: 0.5)
                        .foregroundColor(V3Tokens.mutedText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Divider
            Rectangle()
                .fill(V3Tokens.wash)
                .frame(height: 1)
                .padding(.vertical, 4)
                .accessibilityHidden(true)

            // Mood tag
            HStack(spacing: ONETokens.spacingMD) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(entry.moodColor)
                        .frame(width: 7, height: 7)
                    Text(entry.normalizedMoodLabel.uppercased())
                        .monoLabel(tracking: 1.2)
                        .foregroundColor(V3Tokens.mutedText)
                }
                .padding(.horizontal, ONETokens.spacingMD)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((ONEMood(hex: entry.moodColorHex)?.pastelColor ?? entry.moodColor).opacity(0.12))
                )
            }

            // Share info
            HStack(spacing: ONETokens.spacingMD) {
                // Hava durumu kaldırıldı — prototipte yok ve kaydın anlamına
                // bir şey katmıyordu.
                if entry.shareWithCircle {
                    HStack(spacing: 5) {
                        Text("🌍")
                            .font(V3Typography.sans(11))
                        Text(NSLocalizedString("today.sharedInCircle", comment: ""))
                            .monoLabel()
                            .foregroundColor(V3Tokens.mutedText)
                    }
                }
            }
            .padding(.top, 4)

            if entry.shareWithCircle {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .monoSM()
                    Text(NSLocalizedString("today.circleCanSee", comment: ""))
                        .monoSM(tracking: 0.2)
                }
                .foregroundColor(V3Tokens.mutedText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(V3Tokens.hairline)
                )
            }

            // Note section (if exists)
            if let note = entry.note, !note.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("today.note", comment: ""))
                        .monoLabel(tracking: 1.5)
                        .foregroundColor(V3Tokens.mutedText)

                    Text(note)
                        .bodySM()
                        .foregroundColor(V3Tokens.ink)
                        .lineSpacing(2)
                        .tracking(-0.2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ONETokens.spacingLG)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill((ONEMood(hex: entry.moodColorHex)?.pastelColor ?? entry.moodColor).opacity(0.08))
                )
                .padding(.top, ONETokens.spacingLG)
            }

            // Ritüel 2 adıma indi — eksik kalanlar burada davet olarak duruyor
            optionalExtrasStrip

            // Divider
            Rectangle()
                .fill(V3Tokens.wash)
                .frame(height: 1)
                .padding(.top, 8)
                .accessibilityHidden(true)

            actionButtons
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        // Keşfet butonu kaldırıldı — prototipte kaydedildi ekranının tek
        // birincil eylemi "frekansa dön".
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if entry.photoURL != nil {
                    Button(action: { savePhotoToGallery() }) {
                        HStack(spacing: 5) {
                            Image(systemName: photoSaved ? "checkmark" : "arrow.down.to.line")
                                .monoSM()
                            Text(photoSaved ? NSLocalizedString("today.saved", comment: "") : NSLocalizedString("general.save", comment: ""))
                                .monoBase(tracking: 0.5)
                        }
                        .foregroundColor(photoSaved ? ONETokens.oneGreen : V3Tokens.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(photoSaved ? ONETokens.oneGreen.opacity(0.08) : V3Tokens.surface.opacity(0.5))
                                .overlay(Capsule().stroke(photoSaved ? ONETokens.oneGreen.opacity(0.3) : V3Tokens.hairline, lineWidth: 1))
                        )
                    }
                    .disabled(photoSaved)
                    .accessibilityLabel(photoSaved ? NSLocalizedString("today.saved", comment: "") : NSLocalizedString("general.save", comment: ""))
                    .accessibilityHint(NSLocalizedString("accessibility.today.savePhotoHint", comment: "Fotoğrafı galeriye kaydet"))
                }

                Button(action: {
                    ONEHaptics.feelingSelected()
                    showShareOptions = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .monoSM()
                        Text(NSLocalizedString("general.share", comment: ""))
                            .monoBase(tracking: 0.5)
                    }
                    .foregroundColor(V3Tokens.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .liquidGlass(.regular.interactive(), in: Capsule())
                }
                .accessibilityLabel(NSLocalizedString("accessibility.today.shareButton", comment: ""))
                .accessibilityHint(NSLocalizedString("accessibility.today.shareHint", comment: "Günlük kaydınızı paylaşın"))

                // Değiştir — tertiary, küçük metin butonu
                Button(action: {
                    ONEHaptics.feelingSelected()
                    showChangeConfirm = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .monoLabel()
                        Text(NSLocalizedString("accessibility.today.changeEntry", comment: ""))
                            .bodySM()
                    }
                    .foregroundColor(V3Tokens.mutedText.opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("accessibility.today.changeEntry", comment: ""))
                .accessibilityHint(NSLocalizedString("accessibility.today.changeHint", comment: "Bugünün kaydını değiştir"))
            }
        }
    }

    // MARK: - "İstersen ekle" şeridi

    /// Foto ve not artık ritüelin zorunlu adımları değil. Eksik olanlar
    /// burada davet olarak duruyor — akışı bloklamadan.
    @ViewBuilder
    private var optionalExtrasStrip: some View {
        let needsPhoto = entry.photoURL == nil && onAddPhoto != nil
        let needsNote  = (entry.note?.isEmpty ?? true) && onAddNote != nil

        if needsPhoto || needsNote {
            VStack(alignment: .leading, spacing: ONETokens.spacingSM) {
                Text("İSTERSEN EKLE")
                    .monoSM(tracking: 1.5)
                    .foregroundStyle(V3Tokens.faintText)

                HStack(spacing: ONETokens.spacingSM) {
                    if needsPhoto {
                        extraButton(icon: "camera", title: "fotoğraf", action: onAddPhoto)
                    }
                    if needsNote {
                        extraButton(icon: "pencil", title: "bir şey yaz", action: onAddNote)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, ONETokens.spacingLG)
        }
    }

    private func extraButton(icon: String, title: String, action: (() -> Void)?) -> some View {
        Button(action: { action?() }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(V3Tokens.mutedText)
                Text(title)
                    .font(ONETypography.bodyXS)
                    .fontWeight(.medium)
                    .foregroundStyle(V3Tokens.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ONETokens.spacingLG)
            .background(
                RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                    .fill(V3Tokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: ONETokens.radiusCardLg, style: .continuous)
                            .strokeBorder(V3Tokens.ink.opacity(0.10),
                                          style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Save Photo to Gallery

    private func savePhotoToGallery() {
        guard let photoURL = entry.photoURL,
              let data = try? Data(contentsOf: photoURL),
              let image = UIImage(data: data) else { return }

        ONEHaptics.feelingSelected()
        ShareManager.shared.saveToPhotoLibrary(image: image) { result in
            if case .success = result {
                withAnimation(ONEAnimation.micro) { photoSaved = true }
            }
        }
    }
}
